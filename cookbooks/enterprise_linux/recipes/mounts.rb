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
template '/etc/fstab' do
  source 'etc/fstab.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

node['linux']['mounts'].each do |_key, mount|
  if mount['fs_type'].include?('swap')
    next
  end

  ###
  ### Make and/or manage the directories even when recursive.
  ###

  elements = mount['mount_point'].split('/')
  elements.shift()
  cwd = ''
  elements.each do |element|
    cwd = cwd + '/' + element
    directory cwd do
      owner mount['owner']
      group mount['group']
      mode mount['mode']
      action :create
    end
  end

  execute "Ensure #{mount['mount_point']} is mounted with expected options" do
    command "/usr/bin/mount -o remount #{mount['mount_point']}"
    action :run
    only_if "grep \" #{mount['mount_point']} \" /proc/mounts"
  end
end

execute 'Ensure mounts are mounted' do
  command '/usr/bin/mount -a'
  action :run
end

execute 'Ensuring swap is enabled' do
  command '/usr/sbin/swapon -a'
  action :run
  ### Only if guards here...
end
