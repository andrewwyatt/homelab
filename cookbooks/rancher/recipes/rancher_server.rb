###
### Cookbook:: lab_management
### Recipe:: rancher_server
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

node.default['linux']['firewall']['ports']['443/tcp']     = true
node.default['linux']['firewall']['ports']['2376/tcp']    = true
node.default['linux']['firewall']['ports']['6443/tcp']    = true
node.default['linux']['firewall']['ports']['2379/tcp']    = true
node.default['linux']['firewall']['ports']['2380/tcp']    = true
node.default['linux']['firewall']['ports']['8472/udp']    = true
node.default['linux']['firewall']['ports']['9099/tcp']    = true
node.default['linux']['firewall']['ports']['10250/tcp']   = true

node.default['linux']['firewall']['ignoreexisting']       = true
node.default['linux']['sysctl']['net.ipv4.conf.all.forwarding'] = "1"


###
### Prerequisites
###

yum_package [ 'nfs-utils' ] do
  action :install
end

###
### Inherit the standard server configuration.
###

include_recipe 'lab_management::standard_server'

###
### Configuration to become a rancher server (work in progress)
###

yum_package [ 'docker',
              'docker-compose' ] do
  action :install
end

service "docker" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

template "/etc/monit.d/docker" do
  source "etc/monit.d/docker.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :immediately
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

tag('docker')
tag('rancher')
