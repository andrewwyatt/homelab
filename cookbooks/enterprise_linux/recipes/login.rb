###
### Cookbook Name:: enterprise_linux
### Recipe:: login
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

template '/etc/login.defs' do
  owner 'root'
  group 'root'
  mode  '0644'
  source 'etc/login.defs.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

template '/etc/bashrc' do
  owner 'root'
  group 'root'
  mode  '0644'
  source 'etc/bashrc.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

file '/etc/shadow' do
  owner 'root'
  group 'root'
  mode  '0000'
  sensitive node['linux']['runtime']['sensitivity']
end

file '/etc/passwd' do
  owner 'root'
  group 'root'
  mode  '0644'
  sensitive node['linux']['runtime']['sensitivity']
end

bash "Ensure inactive users are disabled after 35 days" do
  code <<-EOF
    INA=`grep "^INACTIVE" /etc/default/useradd`
    if [[ ! ${INA} =~ ^INACTIVE ]]
    then
      echo "INACTIVE=#{node['linux']['login']['inactive_user_lock_days']}" >>/etc/default/useradd
    else
      sed -i -s -e 's/^INACTIVE.*$/INACTIVE=#{node['linux']['login']['inactive_user_lock_days']}/' /etc/default/useradd
    fi
  EOF
  sensitive node['linux']['runtime']['sensitivity']
  only_if { node['linux']['login']['lock_inactive_users'] == true }
end
