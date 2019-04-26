###
### Cookbook Name:: enterprise_linux
### Recipe:: local_users
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
### This is where we want to maintain any local user access controls
###

###
### The encrypted payload password is stored in credentials -> passwords
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

###
### Disable Root User - Force use of sudo.  If enabled, use the password hash stored in the data bag.
###

user "root" do
  uid 0
  gid 0
  shell "/sbin/nologin"
  home "/root"
  comment "root"
  password "!"
  manage_home false
  action :modify
  only_if { node['linux']['disable_root'] == true }
end

user "root" do
  uid 0
  gid 0
  shell "/bin/bash"
  home "/root"
  comment "root"
  password passwords['root_hash']
  manage_home false
  action :modify
  only_if { node['linux']['disable_root'] == false }
end

user "root" do
  action :lock
  only_if { node['linux']['disable_root'] == true }
end

user "root" do
  action :unlock
  only_if { node['linux']['disable_root'] == false }
end

bash "Ensure local account controls are applied" do
  code <<-EOF
     for user in $(awk 'BEGIN { FS=":" } /1/ { print $1 }' /etc/shadow)
     do
       chage -m #{node['linux']['logindefs']['pass_min_days']} -M #{node['linux']['logindefs']['pass_max_days']} -W #{node['linux']['logindefs']['pass_warn_age']} ${user}
     done
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end
