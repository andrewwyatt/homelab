###
### Cookbook:: provisioned_services
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

node.from_file(run_context.resolve_attribute("provisioned_services", "secrets"))
node.from_file(run_context.resolve_attribute("enterprise_linux", "default"))
node.from_file(run_context.resolve_attribute("provisioner", "default"))

###
### This recipe combines packaging, mirroring, and node building
### into a single VM.
###

###
### Packaging and mirroring ports
###

node.normal['linux']['firewall']['services']['rsyncd']   = true
node.normal['linux']['firewall']['ports']['80/tcp']      = true
node.normal['linux']['firewall']['ports']['443/tcp']     = true

###
### OS provisioning ports
###

node.normal['linux']['firewall']['services']['dhcp' ]    = true
node.normal['linux']['firewall']['ports']['80/tcp']      = true
node.normal['linux']['firewall']['ports']['53/tcp']      = true
node.normal['linux']['firewall']['ports']['53/udp']      = true
node.normal['linux']['firewall']['ports']['69/tcp']      = true
node.normal['linux']['firewall']['ports']['69/udp']      = true
node.normal['linux']['firewall']['ports']['443/tcp']     = true
node.normal['linux']['firewall']['ports']['4011/udp']    = true

###
### Package storage
###

node.normal['linux']['mounts']['data']['device']         = '/dev/wwwvg/lv_www'
node.normal['linux']['mounts']['data']['mount_point']    = '/var/www'
node.normal['linux']['mounts']['data']['fs_type']        = 'ext4'
node.normal['linux']['mounts']['data']['mount_options']  = 'defaults,nosuid,nodev'
node.normal['linux']['mounts']['data']['dump_frequency'] = '1'
node.normal['linux']['mounts']['data']['fsck_pass_num']  = '2'
node.normal['linux']['mounts']['data']['owner']          = 'root'
node.normal['linux']['mounts']['data']['group']          = 'root'
node.normal['linux']['mounts']['data']['mode']           = '0755'

include_recipe 'provisioned_services::standard_server'

include_recipe 'provisioner::replicator'
include_recipe 'provisioner::packager'
include_recipe 'provisioner::provisioner'
