###
### Cookbook Name:: enterprise_linux
### Recipe:: jumpcloud
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
### Disable the service if the authentication mechanism is switched.
###

service 'jcagent' do
  action [:disable, :stop]
  not_if { node['linux']['authentication']['mechanism'] == 'jumpcloud' }
end

unless node['linux']['authentication']['mechanism'] == 'jumpcloud'
  return
end

###
### Encrypted passwords are stored in the credentials > passwords encrypted
### data bag.
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

###
### Install the JumpCloud agent and bootstrap it to the service
###

execute 'install_agent' do
  command "curl --tlsv1.2 --silent --show-error --header 'x-connect-key: #{passwords['jumpcloud']}' '#{node['fqdn']}' | bash >/dev/null 2>&1"
  path    [ '/sbin', '/bin', '/usr/sbin', '/usr/bin' ]
  timeout 600
  not_if { File.exists? "/opt/jc/policyConf.json" }
end
