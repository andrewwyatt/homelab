###
### Cookbook Name:: provisioner
### Default Attributes
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
### *** NOTICE *** NOTICE *** NOTICE *** NOTICE *** NOTICE *** NOTICE ***
###
### READ THIS ATTRIBUTES DEFINITION IN ITS ENTIRETY.  IT MUST BE CONFIGURED
### FOR YOUR ENVIRONMENT, OR IT WILL FAIL TO WORK PROPERLY.
###
### *** NOTICE *** NOTICE *** NOTICE *** NOTICE *** NOTICE *** NOTICE ***
###

###
### Define sensitivity as an attribute so we can override it when necessary
### for troubleshooting purposes.
###

default['provisioner']['runtime']['sensitivity']                = true

###
### Set up the file header to follow the enterprise linux header.
###

default['provisioner']['file_header']                          = node['linux']['chef']['file_header']

###
### Use the ACME shell script to provision the certificate (also requires zonomi DNS)
###

default['provisioner']['ssl']['enabled']                        = true
default['provisioner']['ssl']['use_acme']                       = true
default['provisioner']['ssl']['renewal_day']                    = '7'
default['provisioner']['ssl']['acme_giturl']                    = 'https://github.com/Neilpang/acme.sh.git'

default['provisioner']['name_gen_path']                         = '/var/www/names'
default['provisioner']['max_num_hosts']                         = '9999'
default['provisioner']['name_gen_reset']                        = '900'
default['provisioner']['hostname_auth_token']                   = 'AUTH TOKEN GOES HERE'

default['provisioner']['chef']['default_server']                = "#{node['provisioner']['hostname_prefix']}0001.#{node['provisioner']['domain']}"

default['provisioner']['mirror_host']                           = "mirror.#{node['provisioner']['domain']}"
default['provisioner']['deployment_host']                       = "deploy.#{node['provisioner']['domain']}"
default['provisioner']['builder_host']                          = "build7.#{node['provisioner']['domain']}"

default['provisioner']['subnet']                                = '10.100.100.0'
default['provisioner']['netmask']                               = '255.255.255.0'
default['provisioner']['routers']                               = '10.100.100.1'
default['provisioner']['domain_name_servers']                   = '8.8.8.8, 8.8.4.4'
default['provisioner']['dhcp_range']                            = '10.100.100.170 10.100.100.240'
default['provisioner']['dhcp_default_lease_time']               = '21600'
default['provisioner']['dhcp_max_lease_time']                   = '43200'

default['provisioner']['cobbler']['use_https']                  = '1'
default['provisioner']['cobbler']['port']                       = '443'

default['provisioner']['manage_dns']                            = '0'
default['provisioner']['manage_forward_zones']                  = ''
default['provisioner']['manage_reverse_zones']                  = ''

default['provisioner']['manage_dhcp']                           = '1'
default['provisioner']['next_server']                           = node['fqdn']
default['provisioner']['pxe_just_once']                         = '1'
default['provisioner']['register_new_installs']                 = '1'
default['provisioner']['cobbler_server']                        = node['fqdn']

default['provisioner']['cobbler']['hostname_url']                = "https://#{node['provisioner']['deployment_host']}/get/hostname"
default['provisioner']['cobbler']['bootstrap_url']               = "https://#{node['provisioner']['chef']['default_server']}/node"
default['provisioner']['cobbler']['pxe_timeout']                 = '10'

default['provisioner']['cobbler']['build_notice']                = "Oh, a new server has appeared!  I'll provision it with $profile_name."
default['provisioner']['cobbler']['hostname_notice']             = "This node will be known as ${HOSTNAME}."
default['provisioner']['cobbler']['provisioning_notice']         = "Provisioning..${HOSTNAME} This may take a few minutes."
default['provisioner']['cobbler']['bootstrap_notice']            = "The OS is installed, now I will bootstrap ${HOSTNAME} to #{node['provisioner']['chef']['default_server']}"
default['provisioner']['cobbler']['bootstrap_success_notice']    = "Bootstrap of ${HOSTNAME} to #{node['provisioner']['chef']['default_server']} was successful."
default['provisioner']['cobbler']['bootstrap_failure_notice']    = "There was an error bootstrapping ${HOSTNAME} to #{node['provisioner']['chef']['default_server']}, drop everything and get on it!"

default['provisioner']['cobbler']['build_failure_notice']        = 'Something went wrong building ${HOSTNAME}, better check it out.'
default['provisioner']['cobbler']['build_success_notice']        = '${HOSTNAME} provisioning complete.'
default['provisioner']['cobbler']['decom_schedule']              = '00 * * * *'

default['provisioner']['cobbler']['default_packages']            = { 'core' => '@core' }

default['provisioner']['cobbler']['bootimage_path']              = '/var/www/html/images'

default['provisioner']['cobbler']['bootimages']                  = { 'vmlinuz'    => "https://#{node['provisioner']['mirror_host']}/mirrors/centos/7/os/x86_64/images/pxeboot/vmlinuz",
                                                                     'initrd.img' => "https://#{node['provisioner']['mirror_host']}/mirrors/centos/7/os/x86_64/images/pxeboot/initrd.img" }

default['provisioner']['cobbler']['default_profile']             = node['linux']['cobbler']['profile']
default['provisioner']['cobbler']['distros']                     = { 'CentOS-7-x86_64' => { 'name'       => 'CentOS-7-x86_64',
                                                                                            'owners'     => 'admin',
                                                                                            'kernel'     => "/var/www/html/images/CentOS-7-x86_64/pxeboot/vmlinuz",
                                                                                            'initrd'     => "/var/www/html/images/CentOS-7-x86_64/pxeboot/initrd.img",
                                                                                            'ksmeta'     => "tree=https://#{node['provisioner']['mirror_host']}/mirrors/centos/7/os/x86_64",
                                                                                            'arch'       => 'x86_64',
                                                                                            'breed'      => 'redhat',
                                                                                            'os-version' => 'rhel7',
                                                                                            'repos'      => { 'base'    => "https://#{node['provisioner']['mirror_host']}/mirrors/centos/7/os/x86_64",
                                                                                                              'updates' => "https://#{node['provisioner']['mirror_host']}/mirrors/centos/7/updates/x86_64",
                                                                                                              'extras'  => "https://#{node['provisioner']['mirror_host']}/mirrors/centos/7/extras/x86_64",
                                                                                                              'epel'    => "https://#{node['provisioner']['mirror_host']}/mirrors/epel/7/x86_64/",
                                                                                                              'stable'  => "https://#{node['provisioner']['mirror_host']}/mirrors/local/7/STABLE/RPMS"
                                                                                                            }
                                                                                         }
                                                                   }

default['provisioner']['cobbler']['repos']                       = { 'CentOS-7-x86_64' => { 'name'          => 'CentOS-7-x86_64',
                                                                                            'arch'          => 'x86_64',
                                                                                            'breed'         => 'yum',
                                                                                            'keep-updated'  => 'False',
                                                                                            'mirror'        => "https://#{node['provisioner']['mirror_host']}/mirrors/centos/7/os/x86_64/",
                                                                                            'owners'        => 'admin' }}

default['provisioner']['cobbler']['profiles']                    = { 'CentOS-7-x86_64' => { 'name'                => 'CentOS-7-x86_64',
                                                                                            'distro'              => 'CentOS-7-x86_64',
                                                                                            'enable-menu'         => 'True',
                                                                                            'kickstart'           => '/var/lib/cobbler/kickstarts/CentOS-7-x86_64',
                                                                                            'name-servers'        => '10.100.100.10',
                                                                                            'name-servers-search' => node['provisioner']['domain'] }}

default['provisioner']['cobbler']['systems']                     = { 'default' => { 'name'            => 'default',
                                                                                    'profile'         => node['provisioner']['cobbler']['default_profile'],
                                                                                    'netboot-enabled' => 'True' }}

default['provisioner']['conf']                                  = "epel-#{node['platform_version'][0]}-x86_64"
default['provisioner']['user']                                  = 'builder'
default['provisioner']['package_group']                         = 'packages'
default['provisioner']['package_members']                       = [ 'builder' ]
default['provisioner']['mode']                                  = '0775'
default['provisioner']['path']                                  = '/opt/builder'
default['provisioner']['shell']                                 = '/bin/bash'
default['provisioner']['key_path']                              = 'signing_keys'
default['provisioner']['key_name']                              = 'signing_key.pvt'
default['provisioner']['debug']                                 = 'false'
default['provisioner']['buildpath']                             = '/opt'
default['provisioner']['mockpath']                              = '/opt/mock'
default['provisioner']['resultpath']                            = '${MOCKPATH}/${CONF}/result'
default['provisioner']['reporoot']                              = '/opt/store'
default['provisioner']['baserepopath']                          = "#{node['provisioner']['reporoot']}/#{node['platform_version'][0]}"
default['provisioner']['uploadpath']                            = "/opt/store/#{node['platform_version'][0]}/UPLOADS"
default['provisioner']['failedpath']                            = "/opt/store/#{node['platform_version'][0]}/FAILED"
default['provisioner']['repopath']                              = '${BASEREPOPATH}/STABLE'
default['provisioner']['watch_schedule']                        = '* * * * *'
default['provisioner']['repositories']                          = { 'stable'   => 'STABLE',
                                                                    'testing'  => 'TESTING',
                                                                    'unstable' => 'UNSTABLE' }

default['provisioner']['slack_enabled']                         = false
default['provisioner']['slack_channel']                         = '#homelab'
default['provisioner']['api_path']                              = 'API KEY GOES HERE'

default['provisioner']['kickstart_emoji']                       = ':construction_worker:'

default['provisioner']['replicator_emoji']                      = ':building_construction:'

default['provisioner']['builder_emoji']                         = ':building_construction:'

default['provisioner']['linkname']                              = 'store'
default['provisioner']['webroot']                               = '/var/www/html'
default['provisioner']['pubkey']                                = "RPM-GPG-KEY-LAB-#{node['platform_version'][0]}"

default['provisioner']['rsync_excludes']                        = '--exclude "local*" --exclude "drpms/" --exclude "SRPMS/" --exclude "i386/" --exclude "ppc64*" --exclude "aarch64*" --exclude "debug" --exclude "isos" --exclude "*SHA256"'
default['provisioner']['retry_delay']                           = '30'
default['provisioner']['mirrorroot']                            = "#{node['provisioner']['webroot']}/mirrors"
default['provisioner']['mirrors']                               = { 'centos-7' => { 'name'            => 'centos_7',
                                                                                    'url'             => 'rsync://mirror.atlantic.net/centos/7/',
                                                                                    'gpg_key_url'     => 'http://mirror.atlantic.net/centos/',
                                                                                    'gpg_key_name'    => 'RPM-GPG-KEY-CentOS-7',
                                                                                    'gpg_key_path'    => "#{node['provisioner']['mirrorroot']}/centos/",
                                                                                    'mirror_path'     => "#{node['provisioner']['mirrorroot']}/centos/7/",
                                                                                    'mirror_schedule' => '00 00 * * *',
                                                                                    'enabled'         => true
                                                                                  },
                                                                    'epel-7'   => { 'name'            => 'epel_7',
                                                                                    'url'             => 'rsync://download-ib01.fedoraproject.org/fedora-epel/7/',
                                                                                    'gpg_key_url'     => 'http://archive.fedoraproject.org/pub/epel/',
                                                                                    'gpg_key_name'    => 'RPM-GPG-KEY-EPEL-7',
                                                                                    'gpg_key_path'    => "#{node['provisioner']['mirrorroot']}/epel/",
                                                                                    'mirror_path'     => "#{node['provisioner']['mirrorroot']}/epel/7/",
                                                                                    'mirror_schedule' => '30 00 * * *',
                                                                                    'enabled'         => true
                                                                                  },
                                                                    'local-7'  => { 'name'            => 'local_7',
                                                                                    'url'             => "rsync://#{node['provisioner']['builder_host']}/store/7/",
                                                                                    'gpg_key_url'     => "https://#{node['provisioner']['builder_host']}/store/",
                                                                                    'gpg_key_name'    => "RPM-GPG-KEY-LOCAL-7",
                                                                                    'gpg_key_path'    => "#{node['provisioner']['mirrorroot']}/local/",
                                                                                    'mirror_path'     => "#{node['provisioner']['mirrorroot']}/local/7/",
                                                                                    'mirror_schedule' => '*/5 * * * *',
                                                                                    'enabled'         => true
                                                                    }
                                                                  }


default['provisioner']['common']['rsync']['pid_file']                      = '/var/run/rsyncd.pid'
default['provisioner']['common']['rsync']['uid']                           = 'nobody'
default['provisioner']['common']['rsync']['gid']                           = 'nobody'
default['provisioner']['common']['rsync']['use_chroot']                    = 'yes'
default['provisioner']['common']['rsync']['read_only']                     = 'yes'
default['provisioner']['common']['rsync']['hosts_allow']                   = '10.100.100.0/255.255.255.0'
default['provisioner']['common']['rsync']['hosts_deny']                    = '*'
default['provisioner']['common']['rsync']['max_connections']               = '5'
default['provisioner']['common']['rsync']['log_format']                    = '%t %a %m %f %b'
default['provisioner']['common']['rsync']['syslog_facility']               = 'local3'
default['provisioner']['common']['rsync']['timeout']                       = '300'

default['provisioner']['packager']['rsync']['repository_name']               = "store"
default['provisioner']['packager']['rsync']['repository_path']               = node['provisioner']['reporoot']
default['provisioner']['packager']['rsync']['repository_comment']            = "Internal Package Service for EL#{node['platform_version'][0]}"

default['provisioner']['replicator']['rsync']['repository_name']             = "mirror"
default['provisioner']['replicator']['rsync']['repository_path']             = node['provisioner']['webroot']
default['provisioner']['replicator']['rsync']['repository_comment']          = "Internal CentOS Mirror Service"
