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
  command "curl --tlsv1.2 --silent --show-error --header 'x-connect-key: #{passwords['jumpcloud_connect']}' '#{node['linux']['jumpcloud']['ks_url']}' | bash"
  sensitive node['linux']['runtime']['sensitivity']
  not_if { File.exists? "/opt/jc/jcagent.conf" }
end

execute 'Wait for agent configuration to arrive.' do
  command 'while [ 1 ]; do if [[ "$(cat /opt/jc/jcagent.conf 2>/dev/null)" =~ systemKey ]]; then break; fi; sleep 1; done'
  sensitive node['linux']['runtime']['sensitivity']
  not_if { File.exists? "/opt/jc/jcagent.conf" }
end

###
### Add the server to the appropriate group if it doesn't already exist.
###

sgmembers=`curl -X GET "#{node['linux']['jumpcloud']['api_url']}/v2/systemgroups/#{node['linux']['jumpcloud']['server_groupid']}/membership" \
           -H 'Accept: application/json'       \
           -H 'Content-Type: application/json' \
           -H 'x-api-key: #{passwords['jumpcloud_api']}' 2>/dev/null`

if sgmembers.length < 1
  sgmembers = "{}"
end

ruby_block 'Get the systemKey' do
  block do
    localdata = `cat /opt/jc/jcagent.conf 2>/dev/null`

    if localdata.length < 1
      localdata = "{}"
    end

    lattrs = JSON.parse(localdata)
    lattrs = Hash[*lattrs.collect{|h| h.to_a}.flatten]
    node.run_state['systemKey'] = lattrs['systemKey']
  end
end

execute "Ensuring #{node['fqdn']} is assigned to the appropriate system group." do
  command lazy { <<-EOF
    curl -X POST "#{node['linux']['jumpcloud']['api_url']}/v2/systemgroups/#{node['linux']['jumpcloud']['server_groupid']}/members" \
         -H 'Accept: application/json'                 \
         -H 'Content-Type: application/json'           \
         -H 'x-api-key: #{passwords['jumpcloud_api']}' \
         -d '{ "op": "add", "type": "system", "id": "#{node.run_state['systemKey']}" }' 2>/dev/null
    EOF
  }
  action :run
  sensitive node['linux']['runtime']['sensitivity']
  not_if { sgmembers =~ /#{node.run_state['systemKey']}/ }
  only_if { File.exists? "/opt/jc/jcagent.conf" }
end
