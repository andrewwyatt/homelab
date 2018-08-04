###
### Cookbook Name:: enterprise_linux
### Recipe:: dns
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
### Encrypted passwords are stored in the credentials > passwords encrypted
### data bag.
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

execute 'Configure my DNS record' do
  command <<-EOF
    curl -X GET "#{node['linux']['dns']['zonomi_url']}?host=$(hostname -f)&api_key=#{passwords['zonomi_api']}&value=#{node['ipaddress']}&ttl=#{node['linux']['dns']['zonomi_ttl']}&action=SET"
  EOF
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  only_if { node['linux']['dns']['mechanism'] == 'zonomi' }
  not_if { (`host #{node['fqdn']}`).include?(node['ipaddress']) }
end
