###
### Cookbook Name:: enterprise_linux
### Recipe:: cobbler
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

yum_package [ 'ethtool',
              'python-ethtool',
              'koan' ] do
  action :install
end

bash 'Ensuring registration with Cobbler server' do
  code <<-EOF
    koan -l systems --server #{node['linux']['cobbler']['server']} --port #{node['linux']['cobbler']['port']} 2>&1 | grep $(hostname)
    if [ ! $? == 0 ]
    then
      cobbler-register -s #{node['linux']['cobbler']['server']} --profile=#{node['linux']['cobbler']['profile']} -p #{node['linux']['cobbler']['port']} || true
    fi
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end
