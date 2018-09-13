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

directory '/etc/monit.d' do
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

node_list = Array.new
node_list = `knife node list -k /etc/chef/client.pem -c /etc/chef/client.rb`.split("\n")
node_list.sort

###
### We should only ping the node before me, and the node after me in the array of nodes.
###

node_location = node_list.find_index(node['fqdn'])

previous_node = node_location - 1
if previous_node < 0
  previous_node = node_list.length
  previous_node = previous_node - 1
end

next_node = node_location + 1
if next_node >= node_list.length
  next_node = 0
end

ping_nodes = [ node_list[previous_node],
               node_list[next_node] ]

template "/etc/monitrc" do
  source "etc/monitrc.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

template "/etc/monit.d/host" do
  source "etc/monit.d/host.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

template "/etc/monit.d/network" do
  source "etc/monit.d/network.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

template "/etc/monit.d/filesystems" do
  source "etc/monit.d/filesystems.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

template "/etc/monit.d/ping" do
  source "etc/monit.d/ping.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
  variables ({
    :ping_nodes => ping_nodes
    })
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
