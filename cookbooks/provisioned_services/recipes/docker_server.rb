###
### Cookbook:: provisioned_services
### Recipe:: docker
###
### Copyright 2013-2019, Andrew Wyatt
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

node.force_default['linux']['sysctl']['net.ipv4.conf.all.forwarding'] = "1"

###
### Inherit the standard server configuration.
###

include_recipe 'provisioned_services::standard_server'

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
