###
### Cookbook Name:: enterprise_linux
### Recipe:: monit
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

template "/bin/monit-slack" do
  source "usr/bin/monit-slack.erb"
  owner "root"
  group "root"
  mode 0700
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  only_if { node['linux']['monit']['enabled'] == true }
end

###
### Get a list of nodes from Chef, use the list for ping monitors.
###

ping_nodes = Array.new
ping_nodes = `knife node list -k /etc/chef/client.pem -c /etc/chef/client.rb`.split("\n")
ping_nodes.delete(node['fqdn'])

template "/etc/monitrc" do
  source "etc/monitrc.erb"
  owner "root"
  group "root"
  mode 0700
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :immediately
  only_if { node['linux']['monit']['enabled'] == true }
  variables ({
    :ping_nodes => ping_nodes
    })
end

yum_package 'monit' do
  action :install
end

service 'monit' do
  action [:enable, :start]
  only_if { node['linux']['monit']['enabled'] == true }
end

service 'monit' do
  action [:disable, :stop]
  only_if { node['linux']['monit']['enabled'] == false }
end
