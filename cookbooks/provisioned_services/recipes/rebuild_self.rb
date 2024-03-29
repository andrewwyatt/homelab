###
### Cookbook:: provisioned_services
### Recipe:: rebuild_server
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

###
### This recipe will decommission any server that it has been assigned.
###
### The following actions occur on the very next check in:
###
### Removes self from JumpCloud
### Removes self from Zonomi
### Removes self from Chef
### Removes partition table
### Reboot (the node will pxe boot and reprovision)
###

node.normal['linux']['decom']['final_task']   = 'shutdown -r now'
node.normal['linux']['decom']['decom_notice'] = 'You want me to rebuild myself?  Really?  Oh, alright!'

include_recipe 'enterprise_linux::decom'
