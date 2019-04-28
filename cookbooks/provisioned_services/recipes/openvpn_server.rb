###
### Cookbook:: provisioned_services
### Recipe:: nfs_server
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

node.from_file(run_context.resolve_attribute("provisioned_services", "secrets"))
node.from_file(run_context.resolve_attribute("enterprise_linux", "default"))

###
### Firewall and forwarding changes for OpenVPN
###

node.normal['linux']['firewall']['services']['openvpn']        = true
node.normal['linux']['firewall']['masquerade']                 = true

node.normal['linux']['sysctl']['net.ipv4.ip_forward']          = '1'

###
### Encrypted passwords are stored in the credentials > passwords encrypted
### data bag.
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

###
### Inherit the standard server configuration.
###

include_recipe 'provisioned_services::standard_server'

###
### Install and configure the OpenVPN server.
###

yum_package [ 'openvpn',
              'openvpn-auth-ldap'] do
  action :install
end

template "/etc/openvpn/server.conf" do
  source "etc/openvpn/server.conf.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[openvpn@server]', :delayed
end

template "/etc/openvpn/auth/ldap.conf" do
  source "etc/openvpn/auth/ldap.conf.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[openvpn@server]', :delayed
  variables({
    :password  => passwords['openvpn_passwd']
  })
end

remote_file "#{Chef::Config['file_cache_path']}/#{node['openvpn']['easyrsa_package']}" do
  source "#{node['openvpn']['easyrsa_url']}/#{node['openvpn']['easyrsa_version']}/#{node['openvpn']['easyrsa_package']}"
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

execute "Extract EasyRSA-#{node['openvpn']['easyrsa_version']}" do
  command "tar -C /etc/openvpn/ -xzf #{Chef::Config['file_cache_path']}/#{node['openvpn']['easyrsa_package']}; \
           chown -R root:openvpn /etc/openvpn/EasyRSA-#{node['openvpn']['easyrsa_version']}"
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  not_if { Dir.exists?("/etc/openvpn/EasyRSA-#{node['openvpn']['easyrsa_version']}") }
end

template "/etc/openvpn/EasyRSA-#{node['openvpn']['easyrsa_version']}/vars" do
  source "etc/openvpn/easyrsa_vars.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[openvpn@server]', :delayed
end

directory "/etc/openvpn/pki" do
  owner 'root'
  group 'openvpn'
  mode 0750
  action :create
end

execute "Generate Diffie hellman parameters" do
  command "openssl dhparam -out /etc/openvpn/dh2048.pem 2048"
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  not_if { File.exists?("/etc/openvpn/dh2048.pem") }
end

execute "Create TLS Certificate" do
  command "openvpn --genkey --secret /etc/openvpn/#{node['chef']['default_organization']}.tlsauth"
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  not_if { File.exists?("/etc/openvpn/#{node['chef']['default_organization']}.tlsauth") }
end

execute "Initialize EasyRSA" do
  command "EASYRSA_BATCH=true /etc/openvpn/EasyRSA-#{node['openvpn']['easyrsa_version']}/easyrsa init-pki"
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  not_if { File.exists?("/etc/openvpn/pki/openssl-easyrsa.cnf") }
end

execute "Generate CA" do
  command "EASYRSA_BATCH=true /etc/openvpn/EasyRSA-#{node['openvpn']['easyrsa_version']}/easyrsa build-ca nopass"
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  not_if { File.exists?("/etc/openvpn/pki/ca.crt") }
end

execute "Create req for #{node['fqdn']}" do
  command "EASYRSA_BATCH=true /etc/openvpn/EasyRSA-#{node['openvpn']['easyrsa_version']}/easyrsa gen-req #{node['hostname']} nopass"
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  not_if { File.exists?("/etc/openvpn/pki/reqs/#{node['hostname']}.req") }
end

execute "Sign the #{node['fqdn']} req" do
  command "EASYRSA_BATCH=true /etc/openvpn/EasyRSA-#{node['openvpn']['easyrsa_version']}/easyrsa sign-req server #{node['hostname']} nopass"
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  only_if { File.exists?("/etc/openvpn/pki/reqs/#{node['hostname']}.req") }
  not_if { File.exists?("/etc/openvpn/pki/issued/#{node['hostname']}.crt") }
end

link "/etc/openvpn/ca.crt" do
  to "/etc/openvpn/pki/ca.crt"
end

link "/etc/openvpn/server.crt" do
  to "/etc/openvpn/pki/issued/#{node['hostname']}.crt"
end

link "/etc/openvpn/server.key" do
  to "/etc/openvpn/pki/private/#{node['hostname']}.key"
end


tag('openvpn')

service "openvpn@server" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

template '/etc/monit.d/openvpn' do
  source 'etc/monit.d/openvpn.erb'
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

yum_package 'monit' do
  action :install
end

service 'monit' do
  if node['linux']['monit']['enabled'] == false
    action [:disable, :stop]
  elsif node['linux']['monit']['enabled'] == true
    action [:enable, :start]
  end
end
