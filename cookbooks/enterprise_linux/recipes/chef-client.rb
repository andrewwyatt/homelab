###
### Cookbook Name:: enterprise_linux
### Recipe:: chef-client
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
### Encrypted passwords are stored in the credentials > passwords encrypted
### data bag.
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

openssl_decrypt = String.new("openssl aes-256-cbc -a -d -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")
openssl_encrypt = String.new("openssl aes-256-cbc -a -salt -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")

node.default['linux']['chef']['server']=`printf $(grep chef_server_url /etc/chef/client.rb  | sed -s -e "s#^.*//##" -e "s#/.*\\\$##")`

server_version_test = `rpm -qi chef-#{node['linux']['chef']['client_version']} 2>/dev/null`
unless $?.exitstatus == 0
  if node['linux']['chef']['install_via_url'] == true
    install_file = `curl "#{node['linux']['chef']['client_url']}" 2>/dev/null | grep "chef.*.x86_64.rpm" | sed -s -e 's/^.*href="//' -e 's/".*$//' -e 's/<[^>]*>//g' | head -n 1 | awk '{printf $1}'`
    remote_file "#{Chef::Config['file_cache_path']}/#{install_file}" do
      source "#{node['linux']['chef']['client_url']}#{install_file}"
      owner 'root'
      group 'root'
      mode 0640
      action :create
    end
    rpm_package "chef-#{node['linux']['chef']['client_version']} " do
      allow_downgrade true
      source "#{Chef::Config['file_cache_path']}/#{install_file}"
      action :install
    end
  else
    yum_package [ "chef = #{node['linux']['chef']['client_version']} " ] do
      action :install
      flush_cache [ :before ]
    end
  end
end

### Secure the Chef directories so non-root
### users can not access them
directory '/var/chef' do
  owner 'root'
  group 'root'
  mode  '0700'
  only_if { ::Dir.exists?("/var/chef") }
end

directory '/etc/chef' do
  owner 'root'
  group 'root'
  mode  '0700'
  only_if { ::Dir.exists?("/etc/chef") }
end

directory '/etc/opscode' do
  owner 'opscode'
  group 'opscode'
  mode  '0700'
  only_if { ::Dir.exists?("/etc/opscode") }
  only_if "getent passwd opscode"
end

### This directory does not exist by default
directory '/etc/chef/trusted_certs' do
  owner 'root'
  group 'root'
  mode  '0700'
end

remote_file "#{Chef::Config['file_cache_path']}/encrypted_data_bag_secret.enc" do
  source "https://#{node['linux']['chef']['server']}#{node['linux']['chef']['bootstrap_root']}encrypted_data_bag_secret.enc"
  owner 'root'
  group 'root'
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

execute 'Configure data bag secret' do
  command "#{openssl_decrypt} -in #{Chef::Config['file_cache_path']}/encrypted_data_bag_secret.enc -out /etc/chef/encrypted_data_bag_secret"
  action :run
  notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
  notifies :delete, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :delayed
  sensitive node['linux']['runtime']['sensitivity']
  not_if { File.exists? "/etc/chef/encrypted_data_bag_secret" }
end

file "/etc/chef/encrypted_data_bag_secret" do
  owner 'root'
  group 'root'
  mode 0600
  sensitive node['linux']['runtime']['sensitivity']
end

###
### Chef seems to prefer running the client via cron
###

service 'chef-client' do
  supports status: true, restart: true
  action [:disable, :stop]
end

file '/etc/init.d/chef-client' do
  action :delete
end

file '/etc/systemd/system/chef-client.service' do
  action :delete
end

template "/etc/sysconfig/chef-client" do
  source "etc/sysconfig/chef-client.erb"
  mode 0644
  sensitive node['linux']['runtime']['sensitivity']
end

template '/etc/cron.d/chef-client' do
  source 'etc/cron.d/chef-client.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

directory node['linux']['chef']['ohai_plugin_path'] do
  owner 'root'
  group 'root'
  mode  '0700'
  recursive true
  action :create
end

template "/etc/chef/client.rb" do
  source "etc/chef/client.rb.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  variables({
    :fqdn      => node['fqdn'],
    :chefsvr   => node['linux']['chef']['server']
  })
end

template '/usr/bin/chef-health' do
  source 'usr/bin/chef-health.erb'
  owner 'root'
  group 'root'
  mode  0700
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

template '/etc/cron.d/chef-health' do
  source 'etc/cron.d/chef-health.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end
