###
### Cookbook:: provisioned_services
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

node.from_file(run_context.resolve_attribute('provisioned_services', 'secrets'))
node.from_file(run_context.resolve_attribute('enterprise_linux', 'default'))
node.from_file(run_context.resolve_attribute('chef', 'default'))

node.normal['linux']['firewall']['ports']['80/tcp']  = true
node.normal['linux']['firewall']['ports']['443/tcp'] = true

node.normal['linux']['sysctl']['kernel.shmmax']      = '17179869184'
node.normal['linux']['sysctl']['kernel.shmall']      = '4194304'

include_recipe 'provisioned_services::standard_server'

include_recipe 'chef::configure_server'
include_recipe 'chef::configure_manage'
include_recipe 'chef::configure_reporting'
include_recipe 'chef::configure_bootstrap'
include_recipe 'chef::configure_users'
include_recipe 'chef::configure_mirroring'
