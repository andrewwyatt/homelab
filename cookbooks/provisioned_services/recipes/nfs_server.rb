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

node.from_file(run_context.resolve_attribute('provisioned_services', 'secrets'))
node.from_file(run_context.resolve_attribute('enterprise_linux', 'default'))

###
### NFS servers need NFS ports.
###

node.normal['linux']['firewall']['services']['nfs']      = true
node.normal['linux']['firewall']['services']['rpc-bind'] = true
node.normal['linux']['firewall']['services']['mountd']   = true

node.normal['linux']['firewall']['ports']['2049/tcp']    = true
node.normal['linux']['firewall']['ports']['2049/udp']    = true

###
### Mount the NFS volume
###
### Note: The NFS volume was created as a 1.7TB volume using two vDisks in RAID 1.
###
### # mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc
### # pvcreate /dev/md0
### # vgcreate nfsvg /dev/md0
### # lvcreate -n lv_nfs -l 445612 nfsvg
### # mkfs.ext4 /dev/nfsvg/lv_nfs
###

###
### NFS is in the sys volume group in this configuration.
###

node.default['linux']['mounts']['data']['device']         = '/dev/sysvg/lv_nfs'
node.default['linux']['mounts']['data']['mount_point']    = '/exports/data'
node.default['linux']['mounts']['data']['fs_type']        = 'ext4'
node.default['linux']['mounts']['data']['mount_options']  = 'defaults'
node.default['linux']['mounts']['data']['dump_frequency'] = '1'
node.default['linux']['mounts']['data']['fsck_pass_num']  = '2'
node.default['linux']['mounts']['data']['owner']          = 'root'
node.default['linux']['mounts']['data']['group']          = 'root'
node.default['linux']['mounts']['data']['mode']           = '0755'

node.default['nfs']['exports']                            = { 'exports' => { 'mount_point' => '/exports/data',
                                                                             'hosts' => '10.100.100.0/24',
                                                                             'options' => 'rw,sync,no_root_squash,no_subtree_check',
                                                                           },
                                                            }

###
### Inherit the standard server configuration.
###

include_recipe 'provisioned_services::standard_server'

###
### Install and configure the NFS server.
###

tag('nfs')

yum_package [ 'nfs-utils' ] do
  action :install
end

template '/etc/exports' do
  source 'etc/exports.erb'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  notifies :run, 'execute[exportfs]', :delayed
end

execute 'exportfs' do
  command 'exportfs -a'
  action :nothing
end

service 'nfs-server' do
  supports status: true, restart: true
  action [ :enable, :start ]
end

template '/etc/monit.d/nfs' do
  source 'etc/monit.d/nfs.erb'
  owner 'root'
  group 'root'
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
