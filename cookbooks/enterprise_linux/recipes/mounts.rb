###
### Cookbook Name:: enterprise_linux
### Recipe:: mounts
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

### Configure filesystems that are mounted on a system
template "/etc/fstab" do
  source "etc/fstab.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

node['linux']['mounts'].each do |key,mount|

  if mount['fs_type'].include?("swap")
    next
  end

  ###
  ### Manage the directories
  ###

  directory mount['mount_point'] do
    owner mount['owner']
    group mount['group']
    mode mount['mode']
    action :create
  end

  execute "Ensure #{mount['mount_point']} is mounted with expected options" do
    command "mount -o remount #{mount['mount_point']}"
    action :run
    only_if "grep \" #{mount['mount_point']} \" /proc/mounts"
  end

end

execute "Ensure mounts are mounted" do
  command 'mount -a'
  action :run
end

execute "Ensuring swap is enabled" do
  command 'swapon -a'
  action :run
  ### Only if guards here...
end
