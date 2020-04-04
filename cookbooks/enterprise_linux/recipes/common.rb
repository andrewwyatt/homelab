###
### Cookbook Name:: enterprise_linux
### Recipe:: common
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
###  Tag myself to identify my OS platform.
###

tag("el#{node['platform_version'][0]}")

### Better bash prompt
template '/etc/profile.d/prompt.sh' do
  owner 'root'
  group 'root'
  mode 0755
  source 'etc/profile.d/prompt.sh.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

### Common things that get installed all the time
yum_package [ 'wget',
              'curl',
              'lshw',
              'perl',
              'bind-utils',
              'sysstat',
              'screen',
              'logwatch',
              'vlock',
              'scrub',
              'openssh-clients',
              'rsync',
              'rkhunter',
              'yum-utils' ] do
  action :install
end

### Disable ipv6
template '/etc/modprobe.d/ipv6.conf' do
  owner 'root'
  group 'root'
  mode  '0750'
  source 'etc/modprobe.d/no-ipv6.conf.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end
