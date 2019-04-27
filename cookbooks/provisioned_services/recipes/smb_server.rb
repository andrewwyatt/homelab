###
### Cookbook:: provisioned_services
### Recipe:: nfs_server
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

node.from_file(run_context.resolve_attribute("provisioned_services", "secrets"))
node.from_file(run_context.resolve_attribute("enterprise_linux", "default"))

###
### Configure to be a Samba Server
###

node.normal['linux']['firewall']['services']['samba']    = true
node.normal['linux']['firewall']['services']['mdns']     = true

###
### Mount the SMB volume
###
### Note: The SMB volume was created as a 1.8TB volume using two vDisks in RAID 1.
###
### # fdisk /dev/sdb and /dev/sdc, type fd
### # mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1
### # pvcreate /dev/md0
### # vgcreate smbvg /dev/md0
### # lvcreate -n lv_smb -l 465631 smbvg
### # mkfs.ext4 /dev/smbvg/lv_smb
###

node.normal['linux']['mounts']['data']['device']         = '/dev/smbvg/lv_smb'
node.normal['linux']['mounts']['data']['mount_point']    = '/data'
node.normal['linux']['mounts']['data']['fs_type']        = 'ext4'
node.normal['linux']['mounts']['data']['mount_options']  = 'defaults'
node.normal['linux']['mounts']['data']['dump_frequency'] = '1'
node.normal['linux']['mounts']['data']['fsck_pass_num']  = '2'
node.normal['linux']['mounts']['data']['owner']          = 'root'
node.normal['linux']['mounts']['data']['group']          = 'root'
node.normal['linux']['mounts']['data']['mode']           = '0755'

###
### The encrypted payload password is stored in credentials -> passwords
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

###
### Inherit the standard server configuration.
###

include_recipe 'provisioned_services::standard_server'

###
### Install and configure the Samba server.
###

tag('smb')

yum_package [ 'samba',
              'avahi' ] do
  action :install
end

template '/etc/samba/smb.conf' do
  source 'etc/samba/smb.conf.erb'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  notifies :restart, 'service[smb]', :delayed
end

template '/etc/avahi/services/timemachine.service' do
  source 'etc/avahi/services/timemachine.service.erb'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  notifies :restart, 'service[avahi-daemon]', :delayed
end

execute 'Configure Samba Authentication Password' do
  command "smbpasswd -w #{passwords['samba_passwd']}"
  sensitive node['linux']['runtime']['sensitivity']
  action :run
  notifies :restart, 'service[smb]', :delayed
  not_if "strings /var/lib/samba/private/secrets.tdb 2>/dev/null | grep #{passwords['samba_passwd']} >/dev/null 2>&1"
end

service "smb" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

service "nmb" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

service "avahi-daemon" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

template "/etc/monit.d/samba" do
  source "etc/monit.d/samba.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

yum_package 'monit' do
  action :install
end

service 'monit' do
  if node['linux']['monit']['enabled'] == false
    action [:disable, :stop]
  elsif node['linux']['monit']['enabled'] == true
    action [:enable, :start]
  end
end
