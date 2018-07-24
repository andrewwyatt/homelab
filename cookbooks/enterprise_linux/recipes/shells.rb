###
### Cookbook Name:: enterprise_linux
### Recipe:: shells
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

### Configure default shells
template "/etc/shells" do
  source "etc/shells.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

template '/etc/profile.d/history.sh' do
  owner 'root'
  group 'root'
  mode  '0755'
  source 'etc/profile.d/history.sh.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  only_if { node['linux']['shell']['timestamp_history'] == true }
end

file '/etc/profile.d/history.sh' do
  action :delete
  sensitive node['linux']['runtime']['sensitivity']
  not_if { node['linux']['shell']['timestamp_history'] == true }
  only_if { File.exists? '/etc/profile.d/tmout.sh' }
end


template '/etc/profile.d/tmout.sh' do
   owner 'root'
   group 'root'
   mode  '0755'
   source 'etc/profile.d/tmout.sh.erb'
   action :create
   sensitive node['linux']['runtime']['sensitivity']
   only_if { node['linux']['shell']['timeout'] == true }
end


file '/etc/profile.d/tmout.sh' do
  action :delete
  sensitive node['linux']['runtime']['sensitivity']
  only_if { File.exists? '/etc/profile.d/tmout.sh' }
  not_if { node['linux']['shell']['timeout'] == true }
end
