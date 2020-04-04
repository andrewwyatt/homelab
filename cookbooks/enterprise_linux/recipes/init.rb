###
### Cookbook Name:: enterprise_linux
### Recipe:: init
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

template '/etc/sysconfig/init' do
  source 'etc/sysconfig/init.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

template '/etc/init.d/functions' do
  source 'etc/init.d/functions.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

execute "Setting #{node['linux']['target']}" do
  command "systemctl set-default #{node['linux']['target']}.target"
  action :run
  not_if { `systemctl get-default` =~ /#{node['linux']['target']}/ }
  only_if { node['platform_version'] =~ /^7/ }
end

template '/usr/sbin/bootnotice' do
  source 'usr/sbin/bootnotice.erb'
  owner 'root'
  group 'root'
  mode 0750
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :enable, 'service[bootnotice]', :delayed
  only_if { node['platform_version'] =~ /^7/ }
end

template '/usr/sbin/bootnotice' do
  source 'usr/sbin/bootnotice.erb'
  owner 'root'
  group 'root'
  mode 0750
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  only_if { node['platform_version'] =~ /^7/ }
end

template '/usr/lib/systemd/system/bootnotice.service' do
  source 'usr/lib/systemd/system/bootnotice.service.erb'
  owner 'root'
  group 'root'
  mode 0750
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :enable, 'service[bootnotice]', :immediately
  notifies :run, 'execute[Reload systemctl daemons]', :immediately
  only_if { node['platform_version'] =~ /^7/ }
end

execute 'Reload systemctl daemons' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'bootnotice' do
  supports start: true, stop: true
  action [ :nothing ]
end
