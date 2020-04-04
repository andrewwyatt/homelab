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

node.from_file(run_context.resolve_attribute('provisioned_services', 'secrets'))
node.from_file(run_context.resolve_attribute('enterprise_linux', 'default'))
node.from_file(run_context.resolve_attribute('provisioner', 'default'))

###
### This recipe configures mirror nodes that replicate from another mirror node.
###

###
### Disable external mirroring.
###

node.normal['provisioner']['mirrors']['centos-7']['enabled']         = false
node.normal['provisioner']['mirrors']['epel-7']['enabled']           = false
node.normal['provisioner']['mirrors']['local-7']['enabled']          = false

###
### Configure the URL to the internal mirror to replicate.
###

node.normal['provisioner']['mirrors']['primary']['name']             = 'local_mirror'
node.normal['provisioner']['mirrors']['primary']['url']              = 'rsync://{YOUR_PRIMARY_MIRROR_HERE}/mirror'
node.normal['provisioner']['mirrors']['primary']['mirror_schedule']  = '*/5 * * * *'
node.normal['provisioner']['mirrors']['primary']['mirror_path']      = '/var/www/html'
node.normal['provisioner']['mirrors']['primary']['enabled']          = true

###
### Mirror hosting ports
###

node.normal['linux']['firewall']['ports']['80/tcp']      = true
node.normal['linux']['firewall']['ports']['443/tcp']     = true

include_recipe 'provisioned_services::standard_server'

include_recipe 'provisioner::replicator'
