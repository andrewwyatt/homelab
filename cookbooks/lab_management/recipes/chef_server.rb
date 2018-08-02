###
### Cookbook:: lab_management
### Recipe:: chef_server
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

node.default['linux']['firewall']['ports']['80/tcp']  = true
node.default['linux']['firewall']['ports']['443/tcp'] = true

node.default['linux']['sysctl']['kernel.shmmax']      = '17179869184'
node.default['linux']['sysctl']['kernel.shmall']      = '4194304'

include_recipe 'lab_management::standard_node'

###
### Needs to be refactored.
###

include_recipe 'chef::configure_server'
include_recipe 'chef::configure_manage'
include_recipe 'chef::configure_reporting'
include_recipe 'chef::configure_bootstrap'
#include_recipe 'chef::configure_users'
include_recipe 'chef::configure_mirroring'
