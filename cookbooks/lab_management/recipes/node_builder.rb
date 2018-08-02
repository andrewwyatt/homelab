###
### Cookbook:: lab_management
### Recipe:: node_builder
###
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

node.default['linux']['firewall']['services']['dhcp' ]    = true
node.default['linux']['firewall']['ports']['80/tcp']      = true
node.default['linux']['firewall']['ports']['53/tcp']      = true
node.default['linux']['firewall']['ports']['53/udp']      = true
node.default['linux']['firewall']['ports']['69/tcp']      = true
node.default['linux']['firewall']['ports']['69/udp']      = true
node.default['linux']['firewall']['ports']['443/tcp']     = true
node.default['linux']['firewall']['ports']['4011/udp']    = true

node.default['linux']['mounts']['data']['device']         = '/dev/sysvg/lv_www'
node.default['linux']['mounts']['data']['mount_point']    = '/var/www'
node.default['linux']['mounts']['data']['fs_type']        = 'ext4'
node.default['linux']['mounts']['data']['mount_options']  = 'defaults'
node.default['linux']['mounts']['data']['dump_frequency'] = '1'
node.default['linux']['mounts']['data']['fsck_pass_num']  = '2'
node.default['linux']['mounts']['data']['owner']          = 'root'
node.default['linux']['mounts']['data']['group']          = 'root'
node.default['linux']['mounts']['data']['mode']           = '0755'

include_recipe 'lab_management::standard_node'
include_recipe 'provisioner::provisioner'
