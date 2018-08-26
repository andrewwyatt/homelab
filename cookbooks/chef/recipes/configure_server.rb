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
  backup false
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

execute 'chef-nginx-restart' do
  command "chef-server-ctl restart nginx"
  action :nothing
end

###
### If there's a chef config that already exists, but Chef is down, kill it.
###

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
### Create the /etc/opscode directory if it doesn't exist, manage it if it does.
###

directory '/etc/opscode' do
  owner 'root'
  group 'root'
  mode 0755
  action :create
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

###
### Use ACME to generate a certificate if using Zonomi.
###

###
### Configure the Chef server to use the SSL certificates from Let's Encrypt
###

if node['linux']['dns']['mechanism'] == 'zonomi' && node['chef']['ssl']['use_acme'] == true
  node.default['chef']['server_attributes']['nginx']['ssl_certificate'] = "/etc/opscode/#{node['fqdn']}.crt"
  node.default['chef']['server_attributes']['nginx']['ssl_certificate_key'] = "/etc/opscode/#{node['fqdn']}.pem"
end

###
### Does my certificate exist, or is it within the renewal window?
###

currentdate = Date.today.to_time.to_i

if File.exists?("/etc/opscode/#{node['fqdn']}.crt")
  certexpiration = `date -d "$(openssl x509 -enddate -noout -in #{node['chef']['server_attributes']['nginx']['ssl_certificate']} | sed -e 's#notAfter=##')" '+%s'`
else
  certexpiration = currentdate
end

certdaysleft = (certexpiration.to_i - currentdate.to_i)
if certdaysleft < node['chef']['ssl']['renewal_day'].to_i
  renew_now = true
end

###
### Deconstruct the names to pass to acme.sh
###

certnames = String.new
node['chef']['ssl']['hostnames'].each do | type,value |
   certnames = certnames + "-d " + value + " "
end

yum_package [ 'git' ] do
  action :install
  only_if { node['linux']['dns']['mechanism'] == 'zonomi' }
  only_if { node['chef']['ssl']['use_acme'] == true }
  only_if { renew_now == true }
end

git "#{Chef::Config[:file_cache_path]}/acme.sh" do
  repository node['chef']['ssl']['acme_giturl']
  reference 'master'
  action :sync
  sensitive node['chef']['runtime']['sensitivity']
  not_if { Dir.exists?("#{Chef::Config['file_cache_path']}/acme.sh")}
  only_if { node['linux']['dns']['mechanism'] == 'zonomi' }
  only_if { node['chef']['ssl']['use_acme'] == true }
  only_if { renew_now == true }
end

execute 'Creating or renewing certificate' do
  command "ZM_Key=\"#{passwords['zonomi_api']}\" bash acme.sh --force --issue --dns dns_zonomi #{certnames} --fullchain-file /etc/opscode/#{node['fqdn']}.crt --key-file /etc/opscode/#{node['fqdn']}.pem && rm -rf /tmp/acme"
  cwd "#{Chef::Config['file_cache_path']}/acme.sh"
  action :run
  sensitive node['chef']['runtime']['sensitivity']
  notifies :run, 'execute[chef-reconfigure]', :immediately
  only_if { node['linux']['dns']['mechanism'] == 'zonomi' }
  only_if { node['chef']['ssl']['use_acme'] == true }
  only_if { renew_now == true }
end

notification = "Adding the LDAP password."
bash notification do
  code <<-EOF
    chef-server-ctl set-secret ldap bind_password '#{passwords['auth_user']}'
  EOF
  sensitive node['chef']['runtime']['sensitivity']
  only_if { ::File.exists?("/etc/opscode/chef-server-running.json") }
  not_if { (defined?(passwords['auth_user'])).nil? == true }
  not_if { `grep \'bind_password\' /etc/opscode/chef-server-running.json 2>/dev/null`.include?(passwords['auth_user'].to_s)}
  notifies :run, 'execute[chef-reconfigure]', :immediately
end

notification = "Adding the Automate authentication token."
bash notification do
  code <<-EOF
    chef-server-ctl set-secret data_collector token '#{passwords['automate_token']}'
  EOF
  sensitive node['chef']['runtime']['sensitivity']
  only_if { ::File.exists?("/etc/opscode/chef-server-running.json") }
  not_if { (defined?(passwords['automate_token'])).nil? == true }
  not_if { `grep \'#{passwords['automate_token']}\' /etc/opscode/chef-server-running.json 2>/dev/null`.include?(passwords['automate_token'].to_s)}
  notifies :run, 'execute[chef-reconfigure]', :immediately
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

###
### If enabled, generate a Chef Server configuration based on attributes we've defined for our
### operating environments.
###

if node['chef']['manage_chef'] == true
  def walk_config(value,prefix)
    data = String.new
    value.each do | key, value |
      if value.is_a?(Hash)
        data << "[\'#{key}\']"
        data << walk_config(value).to_s
      else
        data << prefix + "[\'#{key}\'] = \'#{value}\'\n"
      end
    end
    return data
  end
  config = Array.new
  output = String.new
  node['chef']['server_attributes'].each do | key, value |
    if value.is_a?(Hash)
      output << walk_config(value,key).to_s
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
