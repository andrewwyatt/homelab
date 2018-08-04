###
### Cookbook:: lab_management
### Recipe:: combined_server
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
### This recipe combines packaging, mirroring, and node building
### into a single VM.
###

###
### Packaging and mirroring ports
###

node.default['linux']['firewall']['services']['rsyncd']   = true
node.default['linux']['firewall']['ports']['80/tcp']      = true
node.default['linux']['firewall']['ports']['443/tcp']     = true

###
### OS provisioning ports
###

node.default['linux']['firewall']['services']['dhcp' ]    = true
node.default['linux']['firewall']['ports']['80/tcp']      = true
node.default['linux']['firewall']['ports']['53/tcp']      = true
node.default['linux']['firewall']['ports']['53/udp']      = true
node.default['linux']['firewall']['ports']['69/tcp']      = true
node.default['linux']['firewall']['ports']['69/udp']      = true
node.default['linux']['firewall']['ports']['443/tcp']     = true
node.default['linux']['firewall']['ports']['4011/udp']    = true

include_recipe 'lab_management::standard_server'

include_recipe 'provisioner::replicator'
include_recipe 'provisioner::packager'
include_recipe 'provisioner::provisioner'
