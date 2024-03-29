###
### Cookbook Name:: enterprise_linux
### Recipe:: sudoers
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

yum_package 'sudo' do
  action :install
end

template '/etc/sudoers' do
  source 'etc/sudoers.erb'
  owner 'root'
  group 'root'
  mode 0440
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

directory '/etc/sudoers.d' do
  owner 'root'
  group 'root'
  mode 0750
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

node['linux']['sudoers']['properties'].each do |key, configitem|
  file "/etc/sudoers.d/#{key}" do
    owner 'root'
    group 'root'
    mode 0440
    action :create
    content configitem
    sensitive node['linux']['runtime']['sensitivity']
  end
end
