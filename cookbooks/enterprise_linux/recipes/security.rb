###
### Cookbook Name:: enterprise_linux
### Recipe:: security
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
### Remove kickstart artifacts from /root
###

ks_artifacts = Array.new
ks_artifacts = [ 'cobbler.ks', 'ks-pre.log', 'anaconda-ks.cfg', 'original-ks.cfg' ]

ks_artifacts.each do | artifact |
  file "/root/#{artifact}" do
    action :delete
  end
end

yum_package 'arpwatch' do
  action :install
end

service "arpwatch" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

yum_package 'psacct' do
  action :install
end

service "psacct" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

###
### This directory must exist to satisfy CIS level 1
###

directory '/root/bin' do
  owner 'root'
  group 'root'
  mode 0700
  action :create
end

file '/boot/grub2/grub.cfg' do
  owner 'root'
  group 'root'
  mode '0600'
  action :create
  only_if { File.exists? '/boot/grub2/grub.cfg' }
end

template '/etc/modprobe.d/blacklist-hardware.conf' do
  owner 'root'
  group 'root'
  mode  '0640'
  source 'etc/modprobe.d/blacklist-hardware.conf.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  only_if { node['linux']['security']['disable_hardware'] == true }
end

template '/etc/modprobe.d/no-usb.conf' do
  owner 'root'
  group 'root'
  mode  '0640'
  source 'etc/modprobe.d/no-usb.conf.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  only_if { node['linux']['security']['disable_usb_autoload'] == true }
end

template '/etc/modprobe.d/no-udf.conf' do
  owner 'root'
  group 'root'
  mode  '0640'
  source 'etc/modprobe.d/no-udf.conf.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  only_if { node['linux']['security']['disable_udf_autoload'] == true }
end

link '/etc/systemd/system/ctrl-alt-del.target' do
  to '/dev/null'
  owner 'root'
  group 'root'
  mode  '0644'
  action :create
  only_if { node['platform_version'] =~ /^7/ }
  only_if { node['linux']['security']['disable_ctrl_alt_delete'] == true }
end

directory '/etc/audit/rules.d' do
  owner 'root'
  group 'root'
  mode  '0750'
  action :create
end

template '/etc/audit/rules.d/audit.rules' do
  source 'etc/audit/audit.rules.erb'
  owner 'root'
  group 'root'
  mode  '0600'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :run, "execute[restart auditd]", :immediately
end

execute 'restart auditd' do
  command '/sbin/service auditd restart'
  sensitive node['chef']['runtime']['sensitivity']
  action :nothing
end

service "auditd" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

yum_package 'xinetd' do
  action :remove
  only_if { node['linux']['security']['remove_xinetd'] == true }
end

yum_package 'telnet-server' do
  action :remove
  only_if { node['linux']['security']['remove_telnet_server'] == true }
end

yum_package 'telnet' do
  action :remove
  only_if { node['linux']['security']['remove_telnet'] == true }
end

yum_package 'rsh-server' do
  action :remove
  only_if { node['linux']['security']['remove_rsh_server'] == true }
end
