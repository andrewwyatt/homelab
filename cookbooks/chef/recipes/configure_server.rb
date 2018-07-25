###
### Cookbook:: chef
### Recipe:: configure_server
###
### Copyright 2013-2018, Andrew Wyatt
###
### Licensed under the Apache License, Version 2.0 (the "License");
### you may not use this file except in compliance with the License.
### You may obtain a copy of the License at
###
###    http://www.apache.org/licenses/LICENSE-2.0
###
### Unless required by applicable law or agreed to in writing, software
### distributed under the License is distributed on an "AS IS" BASIS,
### WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
### See the License for the specific language governing permissions and
### limitations under the License.
###

###
### The encrypted payload password is stored in credentials -> passwords
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

###
### passfile is used to encrypt and decrypt file based Chef secrets.
###

passfile = Random.rand(99999999) * Random.rand(99999999) * Random.rand(99999999)
file "#{Chef::Config[:file_cache_path]}/.#{passfile}" do
  owner 'root'
  group 'root'
  mode 0600
  content passwords['bootstrap_passphrase']
  sensitive true
  action :nothing
end

###
### Install the Chef server core package.
###

server_version_test = `rpm -q chef-server-core --qf "%{VERSION}" | awk '/^[0-9]/ {printf $1}'`
install_file = `curl "#{node['chef']['server_url']}/#{node['platform_version'][0]}/" 2>/dev/null | grep "chef-server-core.*.x86_64.rpm" | sed -s -e 's/^.*href="//' -e 's/".*$//' -e 's/<[^>]*>//g' | head -n 1 | awk '{printf $1}'`
remote_file "#{Chef::Config['file_cache_path']}/#{install_file}" do
  source "#{node['chef']['server_url']}#{node['platform_version'][0]}/#{install_file}"
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['chef']['runtime']['sensitivity']
  only_if { node['chef']['install_from_source'] == true }
  not_if { server_version_test == node['chef']['server_version'] }
end

rpm_package "chef-server-core" do
  allow_downgrade true
  source "#{Chef::Config['file_cache_path']}/#{install_file}"
  action :install
  only_if { node['chef']['install_from_source'] == true }
  not_if { server_version_test == node['chef']['server_version'] }
end

yum_package [ "chef-server-core = #{node['chef']['server_version']}" ] do
  allow_downgrade true
  action :install
  flush_cache [ :before ]
  only_if { node['chef']['install_from_source'] == false }
  not_if { server_version_test == node['chef']['server_version'] }
end

execute 'chef-upgrade' do
  command 'chef-server-ctl upgrade'
  action :run
  sensitive node['chef']['runtime']['sensitivity']
  notifies :run, 'execute[chef-reconfigure]', :immediately
  only_if { server_version_test =~ /\d/ }
  not_if { server_version_test == node['chef']['server_version'] }
end

execute 'chef-restart' do
  command 'chef-server-ctl restart'
  sensitive node['chef']['runtime']['sensitivity']
  action :run
  only_if { server_version_test =~ /\d/ }
  not_if { server_version_test == node['chef']['server_version'] }
end

### Get my upstream Chef server
if node['chef']['sync_host'].empty? == true
  node.default['chef']['sync_host']=`grep chef_server_url /etc/chef/client.rb  | sed -s -e "s#^.*//##" -e "s#/.*\\\$##" | awk '{printf $1}'`
end

###
### Create a reconfigure resource
###

execute 'chef-reconfigure' do
  command "chef-server-ctl reconfigure"
  action :nothing
end

###
### This directory is used to stage the encrypted package that we'll use later for bootstrapping
###

directory node['chef']['keys'] do
  owner 'root'
  group 'root'
  mode 0700
  action :create
end

file "/etc/opscode/chef-server.rb" do
  action :delete
  only_if { node['chef']['manage_chef'] == true }
  not_if { ::File.exists?("/etc/opscode/chef-server-running.json") }
end

###
### If this is a new installation, run Chef Server reconfigure to prepare it for
### use.  If there's an existing configuration before we do, move it temporarily.
###

bash "Chef Server has never been configured, configuring Chef Server." do
  code <<-EOF
    chef-server-ctl reconfigure
  EOF
  not_if { ::File.exists?("/etc/opscode/chef-server-running.json") }
  sensitive node['chef']['runtime']['sensitivity']
end

###
### Creates the administrative users for each org
### The password is credentials -> chef -> admin username -> password
###

node['chef']['organizations'].each do |key,org|
  chef_admin_user_test = `chef-server-ctl user-list 2>/dev/null | grep #{org['admin_user']['username']}`
  unless chef_admin_user_test =~ /#{org['admin_user']['username']}/
    notification = "Creating the #{org['short_name']} admin account."
    password = ""
    passchars='!#%^:,./?1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    length=(16+rand(16))
    (0..length).each do
       paschar=passchars[(rand(passchars.length)-1)]
       password << paschar
    end
    bash notification do
      code <<-EOF
        chef-server-ctl user-create #{org['admin_user']['username']} #{org['admin_user']['first_name']} #{org['admin_user']['last_name']} #{org['admin_user']['email']} #{password} -f #{node['chef']['keys']}/#{org['admin_user']['username']}.pem
      EOF
      only_if { ::File.exists?("/etc/opscode/chef-server-running.json") }
      only_if { ::File.exists?("/usr/bin/chef-server-ctl") }
      sensitive node['chef']['runtime']['sensitivity']
    end
  end
end

###
### Create the organizations, and then add the previously created user as the administrator.
###

node['chef']['organizations'].each do |key,org|
  notification="Creating the #{org['full_name']} organization."
  chef_org_test = `chef-server-ctl org-show "#{org['short_name']}" 2>/dev/null`
  unless $?.exitstatus == 0
    bash notification do
      code <<-EOF
        chef-server-ctl org-create #{org['short_name']} "#{org['full_name']}" --association_user #{org['admin_user']['username']} -f #{node['chef']['keys']}/#{org['short_name']}-validator.pem
      EOF
      sensitive node['chef']['runtime']['sensitivity']
      only_if { ::File.exists?("/etc/opscode/chef-server-running.json") }
      only_if { ::File.exists?("/usr/bin/chef-server-ctl") }
    end
  end
end

notification = "Adding the LDAP password."
bash notification do
  code <<-EOF
    chef-server-ctl set-secret ldap bind_password '#{passwords['ad_bind_account']}'
  EOF
  sensitive node['chef']['runtime']['sensitivity']
  notifies :run, 'execute[chef-reconfigure]', :immediately
  only_if { (defined?(passwords[ad_bind_account])).nil? == false }
  only_if { ::File.exists?("/etc/opscode/chef-server-running.json") }
  not_if { `grep bind_password /etc/opscode/chef-server-running.json 2>/dev/null`.include?(passwords[ad_bind_account])}
end


notification = "Adding the Automate authentication token."
bash notification do
  code <<-EOF
    chef-server-ctl set-secret data_collector token '#{passwords['automate_token']}'
  EOF
  sensitive node['chef']['runtime']['sensitivity']
  only_if { ::File.exists?("/etc/opscode/chef-server-running.json") }
  only_if { (defined?(passwords['automate_token'])).nil? == false }
  not_if { `grep \'#{passwords['automate_token']}\' /etc/opscode/chef-server-running.json 2>/dev/null`.include?(passwords['automate_token']) }
  notifies :run, 'execute[chef-reconfigure]', :immediately
end

###
### Look for a credentials => certificates bag, if it exists, look for the hostname.
### If it doesn't exist, look for the wildcard cert.  If that doesn't exist, provision a local cert.
###

begin
  certificates = data_bag_item('credentials', 'certificates', IO.read(Chef::Config['encrypted_data_bag_secret']))
  certificate = String.new
  key = String.new
  if certificates["#{node['fqdn']}-crt"].nil? == false && certificates["#{node['fqdn']}-key"].nil? == false
    certificate = certificates["#{node['fqdn']}-crt"]
    key = certificates["#{node['fqdn']}-key"]
  elsif certificates["#{node['chef']['runtime']['domain']}-crt"].nil? == false && certificates["#{node['chef']['runtime']['domain']}-key"].nil? == false
    certificate = certificates["#{node['chef']['runtime']['domain']}-crt"]
    key = certificates["#{node['chef']['runtime']['domain']}-key"]
  end
  file "/etc/opscode/#{node['fqdn']}.crt" do
    owner 'opscode'
    group 'opscode'
    mode 0600
    content certificate
    sensitive true
    action :create
    only_if { (defined?(certificate)).empty? == false }
  end

  file "/etc/opscode/#{node['fqdn']}.pem" do
    owner 'opscode'
    group 'opscode'
    mode 0600
    content key
    sensitive true
    action :create
    only_if { (defined?(key)).empty? == false }
  end

rescue

  ###
  ### If there's no defined SSL certificate, set the self generated cert, and
  ### null the key.
  ###

  node.default['chef']['ssl_certificate'] = "/var/opt/opscode/nginx/ca/#{node['fqdn']}.crt"
  node.default['chef']['ssl_certificate_key'] = nil

end

###
### If enabled, generate a Chef Server configuration based on attributes we've defined for our
### operating environments.
###

if node['chef']['manage_chef'] == true
  def walk_config(value)
    data = String.new
    value.each do | key, value |
      data << "[\'#{key}\']"
      if value.is_a?(Hash)
        data << walk_config(value).to_s
      else
        data << " = \'#{value}\'"
      end
    end
    return data
  end
  config = Array.new
  output = String.new
  node['chef']['server_attributes'].each do | key, value |
    if value.is_a?(Hash)
      output << key
      output << walk_config(value).to_s
    else
      output << "#{key} = \'#{value}\'"
    end
    if (defined?(output)).empty? == false
      config.push output
    end
    output = ""
  end
end

template '/etc/opscode/chef-server.rb' do
  source 'etc/opscode/chef-server.rb.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['chef']['runtime']['sensitivity']
  variables ({
    config: config
  })
  notifies :run, 'execute[chef-reconfigure]', :immediately
  only_if { node['chef']['manage_chef'] == true }
end

tag('chef-server')
tag(node['chef']['runtime']['environment'])
