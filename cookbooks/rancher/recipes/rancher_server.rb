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

node.default['linux']['firewall']['ports']['8080/tcp']    = true

###
### Mount the NFS volume
###

node.default['linux']['mounts']['data']['device']         = 'cdc0003.lab.fewt.com:/exports/data'
node.default['linux']['mounts']['data']['mount_point']    = '/exports/data'
node.default['linux']['mounts']['data']['fs_type']        = 'nfs'
node.default['linux']['mounts']['data']['mount_options']  = 'defaults'
node.default['linux']['mounts']['data']['dump_frequency'] = '0'
node.default['linux']['mounts']['data']['fsck_pass_num']  = '0'
node.default['linux']['mounts']['data']['owner']          = 'root'
node.default['linux']['mounts']['data']['group']          = 'root'
node.default['linux']['mounts']['data']['mode']           = '0755'

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

yum_package [ 'docker' ] do
  action :install
end

service "docker" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end
