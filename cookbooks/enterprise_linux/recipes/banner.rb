###
### Cookbook Name:: enterprise_linux
### Recipe:: banner
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

### Configure Banner

file '/etc/issue' do
  owner 'root'
  group 'root'
  mode   0644
  content node['linux']['banner']
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

file '/etc/issue.net' do
  owner 'root'
  group 'root'
  mode   0644
  content node['linux']['banner']
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

file '/etc/motd' do
  owner 'root'
  group 'root'
  mode   0644
  content node['linux']['motd']
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end
