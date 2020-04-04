###
### Cookbook:: chef
### Recipe:: configure_bootstrap
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
### If the license isn't accepted, don't do anything.
###

unless node['chef']['accept_license'] == true
  return
end

###
### Add a feature to Chef Server to serve our bootstrap payload
### URL: https://{chefserver}/#{node['chef']['bootstrap_root']}
###

###
### The encrypted payload password is stored in credentials -> passwords
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

###
### passfile is used to encrypt and decrypt file based Chef secrets.
###

passfile = SecureRandom.uuid
file "#{Chef::Config[:file_cache_path]}/.#{passfile}" do
  owner 'root'
  group 'root'
  mode 0600
  content passwords['bootstrap_passphrase']
  backup false
  sensitive true
  action :nothing
end

openssl_decrypt = String.new("openssl aes-256-cbc -a -d -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")
openssl_encrypt = String.new("openssl aes-256-cbc -a -salt -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")

directory "/var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}" do
  owner 'opscode'
  group 'opscode'
  mode '0750'
  action :create
end

template "/var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}bootstrap" do
  owner 'opscode'
  group 'opscode'
  mode 0644
  action :create
  sensitive node['chef']['runtime']['sensitivity']
  source "var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}bootstrap.erb"
  variables(
    server_name: node['fqdn'],
    client_version: node['chef']['client_version'],
    install_from_source: node['chef']['install_from_source'],
    url: node['chef']['client_url'],
    org_name: node['chef']['default_organization'],
    org_user: node['chef']['bootstrap_user'],
    org_cert: node['chef']['organizations'][node['chef']['default_organization']]['validator'],
    chef_environment: node['chef']['organizations'][node['chef']['default_organization']]['environment'],
    run_list: node['chef']['organizations'][node['chef']['default_organization']]['run_list'],
    bootstrap_root: node['chef']['bootstrap_root'],
    bootstrap_delay: node['chef']['bootstrap_delay']
  )
end

execute 'Restart nginx' do
  command 'chef-server-ctl restart nginx'
  sensitive node['chef']['runtime']['sensitivity']
  action :nothing
end

template '/var/opt/opscode/nginx/etc/addon.d/50-bootstrap_external.conf' do
  source 'var/opt/opscode/nginx/etc/addon.d/50-bootstrap_external.conf.erb'
  owner 'opscode'
  group 'opscode'
  mode 0640
  action :create
  sensitive node['chef']['runtime']['sensitivity']
  notifies :run, 'execute[Restart nginx]', :immediately
end

notification = 'Encrypting the Chef encrypted data bag secret'
bash notification do
  code <<-EOF
    #{openssl_decrypt} -in /var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}encrypted_data_bag_secret.enc >/dev/null 2>&1
    if [ ! "$?" = 0 ]
    then
      #{openssl_encrypt} -in /etc/chef/encrypted_data_bag_secret -out /var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}encrypted_data_bag_secret.enc
    fi
  EOF
  sensitive node['chef']['runtime']['sensitivity']
  notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
  notifies :delete, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :delayed
  only_if { File.exist? '/etc/chef/encrypted_data_bag_secret' }
end

notification = "Encrypting the Chef administrator certificate for user #{node['chef']['organizations'][node['chef']['default_organization']]['admin_user']['username']}"
bash notification do
  code <<-EOF
    #{openssl_decrypt} -in /var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}#{node['chef']['organizations'][node['chef']['default_organization']]['admin_user']['username']}.pem.enc >/dev/null 2>&1
    if [ ! "$?" = 0 ]
    then
      #{openssl_encrypt} -in #{node['chef']['keys']}/#{node['chef']['organizations'][node['chef']['default_organization']]['admin_user']['username']}.pem -out /var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}#{node['chef']['organizations'][node['chef']['default_organization']]['admin_user']['username']}.pem.enc
    fi
  EOF
  sensitive node['chef']['runtime']['sensitivity']
  notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
  notifies :delete, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :delayed
  only_if { File.exist? "#{node['chef']['keys']}/#{node['chef']['organizations'][node['chef']['default_organization']]['admin_user']['username']}.pem" }
end

notification = 'Encrypting the pivotal private key'
bash notification do
  code <<-EOF
  #{openssl_decrypt} -in /var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}pivotal.pem.enc >/dev/null 2>&1
  if [ ! "$?" = 0 ]
  then
    #{openssl_encrypt} -in /etc/opscode/pivotal.pem -out /var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}pivotal.pem.enc
  fi
  EOF
  sensitive node['chef']['runtime']['sensitivity']
  notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
  notifies :delete, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :delayed
  only_if { File.exist? '/etc/opscode/pivotal.pem' }
end

bsfiles = [ "#{node['fqdn']}.crt.enc",
            'encrypted_data_bag_secret.enc',
            "#{node['chef']['organizations'][node['chef']['default_organization']]['admin_user']['username']}.pem.enc",
            'pivotal.pem.enc' ]

node['chef']['organizations'].each do |_key, org|
  notification = "Encrypting the #{org['full_name']} validator certificate."
  bash notification do # ~FC022
    code <<-EOF
      #{openssl_decrypt} -in /var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}#{org['short_name']}-validator.pem.enc >/dev/null 2>&1
      if [ ! "$?" = 0 ]
      then
        #{openssl_encrypt} -in #{node['chef']['keys']}/#{org['short_name']}-validator.pem -out /var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}#{org['short_name']}-validator.pem.enc
      fi
   EOF
    sensitive node['chef']['runtime']['sensitivity']
    notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
    notifies :delete, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :delayed
    only_if { File.exist? "#{node['chef']['keys']}/#{org['short_name']}-validator.pem" }
  end
  bsfiles << "#{org['short_name']}-validator.pem.enc"
end

bsfiles.each do |bsfile|
  file "/var/opt/opscode/nginx/html#{node['chef']['bootstrap_root']}#{bsfile}" do
    owner 'opscode'
    group 'opscode'
    mode 0644
    sensitive node['chef']['runtime']['sensitivity']
    action :create
  end
end
