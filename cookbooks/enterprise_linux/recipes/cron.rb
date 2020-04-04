###
### Cookbook Name:: enterprise_linux
### Recipe:: cron
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

### Restrict Cron access
template '/etc/cron.allow' do
  owner 'root'
  group 'root'
  mode   0600
  source 'etc/cron.allow.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

file '/etc/crontab' do
  owner 'root'
  group 'root'
  mode 0600
  sensitive node['linux']['runtime']['sensitivity']
end

cron_dirs = [ '/etc/cron.hourly',
              '/etc/cron.daily',
              '/etc/cron.weekly',
              '/etc/cron.monthly',
              '/etc/cron.d' ]
cron_dirs.each do |dir|
  directory dir do
    owner 'root'
    group 'root'
    mode 0700
  end
end

execute 'Ensure proper ownership of /var/spool/cron' do
  command 'chown -Rf root:root /var/spool/cron'
  sensitive node['linux']['runtime']['sensitivity']
end

execute 'Ensure proper permissions of /var/spool/cron' do
  command 'chmod -f 755 /var/spool/cron ||:'
  command 'chmod -f 644 /var/spool/cron/* ||:'
  sensitive node['linux']['runtime']['sensitivity']
end

yum_package 'at' do
  action :remove
  only_if { node['linux']['security']['remove_at_daemon'] == true }
end

file '/etc/at.allow' do
  owner 'root'
  group 'root'
  mode   0700
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

file '/etc/at.deny' do
  owner 'root'
  group 'root'
  mode   0700
  action :delete
  sensitive node['linux']['runtime']['sensitivity']
end

file '/etc/cron.deny' do
  action :delete
  sensitive node['linux']['runtime']['sensitivity']
end
