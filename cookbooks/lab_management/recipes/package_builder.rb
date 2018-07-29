###
### Cookbook:: lab_management
### Recipe:: package_builder
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

node.default['linux']['firewall']['services']['rsyncd'] = true
node.default['linux']['firewall']['ports']['80/tcp']    = true
node.default['linux']['firewall']['ports']['443/tcp']   = true

include_recipe 'lab_management::standard_node'
include_recipe 'provisioner::packager'
