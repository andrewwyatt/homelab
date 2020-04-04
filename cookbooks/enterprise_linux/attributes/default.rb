###
### Cookbook Name:: enterprise_linux
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
### To install, configure, and use Chef, you must accept the
### licenses.  This is set to false by default forcing the action to be taken by
### the user.
###

###
### The Chef client license can be found at the following URL:
###
### https://www.chef.io/end-user-license-agreement/
###

default['chef']['accept_license']                               = false

###
### Define sensitivity as an attribute so we can override it when necessary
### for troubleshooting purposes.
###

default['linux']['runtime']['sensitivity']                      = true

###
### Defines the organization that Chef Client will use for connections.
###

### Defined in secrets.rb
# default['linux']['organization']                                = "lab.fewt.com"
# default['linux']['org_abbreviation']                            = "lab"

###
### This defines the cname for the local deployment node, as well as the default profile for new servers.
### Inherited by the provisioner cookbook.
###

default['linux']['cobbler']['server']                            = "deploy.#{node['linux']['domain_name']}"
default['linux']['cobbler']['port']                              = '443'
default['linux']['cobbler']['profile']                           = 'CentOS-7-x86_64'

###
### Configures the default timezone for servers
###

default['linux']['timezone']                                     = 'America/New_York'

###
### This defines the Chef package that is used for deployment.  It is shared by other
### cookbooks.  Changes here affect provisioning.
###

default['linux']['chef']['install_branch']                       = 'stable'
default['linux']['chef']['client_version']                       = '15.0.300'
default['linux']['chef']['install_via_url']                      = false
default['linux']['chef']['client_url']                           = "https://packages.chef.io/files/#{node['linux']['chef']['install_branch']}/chef/#{node['linux']['chef']['client_version']}/el/#{node['platform_version'][0]}/"

###
### These attributes define the basic knowledge about the Chef Organization, and how to configure nodes
### to operate in this organization.
###

default['linux']['chef']['chef_org']                             = "/organizations/#{node['linux']['org_abbreviation']}"
default['linux']['chef']['org_cert']                             = "#{node['linux']['org_abbreviation']}-validator"
default['linux']['chef']['default_environment']                  = node['linux']['org_abbreviation']

default['linux']['chef']['primary_role']                         = 'enterprise_linux'
default['linux']['chef']['bootstrap_delay']                      = '10'
default['linux']['chef']['bootstrap_user']                       = 'admin'
default['linux']['chef']['bootstrap_root']                       = '/node/'

default['linux']['chef']['current_dir']                          = 'File.dirname(__FILE__)'
default['linux']['chef']['log_level']                            = ':info'
default['linux']['chef']['log_location']                         = 'STDOUT'
default['linux']['chef']['ohai_plugin_path']                     = '/etc/chef/ohai/plugins'
default['linux']['chef']['cache_type']                           = 'BasicFile'
default['linux']['chef']['cache_options']                        = "\#{ENV['HOME']}/.chef/checksums"
default['linux']['chef']['cookbook_path']                        = "\#{current_dir}/../cookbooks"

default['linux']['chef_client_cron']                             = '00,30 * * * * root /usr/bin/sleep $(( RANDOM \%300 )); chef-client --chef-license accept >/var/log/chef-client.log 2>&1'

default['linux']['chef']['conf_dir']                             = '/etc/chef'
default['linux']['chef']['run_path']                             = '/var/run/chef'

default['linux']['chef']['file_header']                          =
  '###
### **********  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  **********
###
### THIS IS A CHEF MANAGED SERVICE!  CHANGES MADE TO THIS FILE WILL NOT PERSIST!
### IF THIS FILE IS CHANGED, CHEF WILL REVERT IT AND RESTART THE APPLICABLE
### SERVICE!  YOU WILL BE HELD RESPONSIBLE FOR ANY OUTAGE THAT MAY OCCUR!
###
### **********  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  **********
###'

###
### Sets the default banner statement for servers.  This message is displayed when users
### connect to a Chef Managed server.
###

default['linux']['banner'] =
  '
************************************************************************

   WARNING: This system is for the use of authorized clients only.
            Individuals using the computer network system without
            authorization, or in excess of their authorization, are
            subject to having all their activity on this computer
            network system monitored and recorded by system
            personnel.  To protect the computer network system from
            unauthorized use and to ensure the computer network systems
            is functioning properly, system administrators monitor this
            system.  Anyone using this computer network system
            expressly consents to such monitoring and is advised that
            if such monitoring reveals possible conduct of criminal
            activity, system personnel may provide the evidence of
            such activity to law enforcement officers.

            Access is restricted to authorized users only.
            Unauthorized access is a violation of state and federal,
            civil and criminal laws.

**************************************************************************

  '

###
### By default we don't present a message of the day to users post login.
###

default['linux']['motd']                                        = ''

###
### The following attributes are necessary to send messages to Slack.
###
### default['linux']['slack_enabled']                               = false
### default['linux']['slack_channel']                               = '#homelab'
### default['linux']['emoji']                                       = ':construction:'
### default['linux']['api_path']                                    = 'APIKEYGOESHERE'

###
### Sets up the reboot Slack notification.
###

default['linux']['boot_notice_emoji']                           = ':running:'

###
### Sets up the health check notification.
###

default['linux']['health_check_emoji']                          = ':stopwatch:'

###
### Sets up the patching notification
###

default['linux']['patch_emoji']                                 = ':construction:'

###
### The health utility checks the status of itself to ensure it is checking into Chef,
### if it is not checking in properly it will attempt to self heal and warn if unable.
###

default['linux']['chef_health']                                 = '00 * * * * root /usr/bin/sleep $(( RANDOM \%150 ));/usr/bin/chef-health >/var/log/chef-health.log 2>&1'

###
### By default all servers in this environment are configured to patch themselves weekly.
###

default['linux']['autoupdate']                                  = '00 00 * * 1 root /usr/bin/sleep $(( RANDOM \%600 ));/usr/bin/autoupdate --reboot >/var/log/autoupdate.log 2>&1'

###
### The decom recipe also supports rebuilding, this attribute shouldn't normally be changed
### unless the desire is to always rebuild the nodes.
###

default['linux']['decom']['final_task']                          = 'shutdown -h now'

###
### Send this notification that the node is being decommissioned to Slack
###

default['linux']['decom']['decom_notice']                        = 'WHAT? I am being decommissioned!'

###
### Setting disable_root to true will lock out the root user preventing use.  Setting to false
### however will cause the recipe to manage the root password based on the root_hash data bag property
### that is also consumed by the provisioning cookbook.
###

default['linux']['disable_root']                                = true

default['linux']['login']['lock_inactive_users']                = true
default['linux']['login']['inactive_user_lock_days']            = '30'

###
### Valid for EL6 (deprecated)
###

default['linux']['runlevel']                                    = '3'

###
### EL7 uses multi-user.target
###

default['linux']['target']                                      = 'multi-user'

default['linux']['shell']['timeout']                            = '900'
default['linux']['shell']['timestamp_history']                  = true
default['linux']['shells']                                      = { 'bash' => '/bin/bash',
                                                                    'sh' => '/bin/sh',
                                                                    'dash' => '/bin/dash' }

default['linux']['cronallow']                                   = {}
default['linux']['hosts']                                       = {}

default['linux']['dns_search']                                  = "#{node['linux']['domain_name']} #{node['linux']['domain_root']}"
default['linux']['dns_options']                                 = 'timeout:1'
default['linux']['dns_resolvers']                               = { 'ns1' => '8.8.8.8',
                                                                    'ns2' => '8.8.4.4' }

default['linux']['limits']['default'] = { 'hard_core' => '* hard core 0',
                                          'soft_core' => '* soft core 0',
                                          'soft_nproc' => '* soft nproc unlimited' }

default['linux']['selinux']                                     = 'disabled'
default['linux']['selinuxtype']                                 = 'targeted'

default['linux']['logindefs']['maildir']                         = '/var/spool/mail'
default['linux']['logindefs']['pass_max_days']                   = '90'
default['linux']['logindefs']['pass_min_days']                   = '7'
default['linux']['logindefs']['pass_min_len']                    = '14'
default['linux']['logindefs']['pass_warn_age']                   = '7'
default['linux']['logindefs']['uid_min']                         = '500'
default['linux']['logindefs']['uid_max']                         = '60000'
default['linux']['logindefs']['gid_min']                         = '500'
default['linux']['logindefs']['gid_max']                         = '60000'
default['linux']['logindefs']['create_home']                     = 'yes'
default['linux']['logindefs']['umask']                           = '027'
default['linux']['logindefs']['usergroups_enab']                 = 'yes'
default['linux']['logindefs']['encrypt_method']                  = 'SHA512'
default['linux']['logindefs']['fail_delay']                      = '4'
default['linux']['logindefs']['faillog_enab']                    = 'yes'

default['linux']['pwquality']['difok']                           = '5'
default['linux']['pwquality']['minlen']                          = '14'
default['linux']['pwquality']['dcredit']                         = '-1'
default['linux']['pwquality']['ucredit']                         = '-1'
default['linux']['pwquality']['lcredit']                         = '-1'
default['linux']['pwquality']['ocredit']                         = '-1'
default['linux']['pwquality']['minclass']                        = '0'
default['linux']['pwquality']['maxrepeat']                       = '4'

default['linux']['auth']['cracklib']                             = 'retry=3 minlen=14 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1 type='
default['linux']['auth']['password_sufficient']                  = 'remember=5 sha512 shadow nullok try_first_pass use_authtok'

default['linux']['user']['umask']                                = '077'

default['linux']['ntp_servers'] = { 'ntp1' => 'server 0.north-america.pool.ntp.org',
                                    'ntp2' => 'server 1.north-america.pool.ntp.org' }
default['linux']['ntp_restrictions']                             = {}

default['linux']['ntp_options']                                  = { 'tinker0' => 'tinker panic 0' }

default['linux']['dns']['mechanism']                             = 'zonomi'
default['linux']['dns']['zonomi_url']                            = 'https://zonomi.com/app/dns/dyndns.jsp'
default['linux']['dns']['zonomi_ttl']                            = '60'

default['linux']['authentication']['mechanism']                  = 'jumpcloud'
default['linux']['authgroup']['users']                           = 'domain-users'
default['linux']['authgroup']['administrators']                  = 'domain-admins'

default['linux']['jumpcloud']['ks_url']                          = 'https://kickstart.jumpcloud.com/Kickstart'
default['linux']['jumpcloud']['api_url']                         = 'https://console.jumpcloud.com/api'
default['linux']['jumpcloud']['server_groupid']                  = ''

default['linux']['sudoers']['properties']                        = { 'administrators' => "%#{node['linux']['authgroup']['administrators']}	ALL=(ALL) NOPASSWD: ALL" }

default['linux']['monit']['enabled']                             = true
default['linux']['monit']['alert_critical']                      = '#A72B2B'
default['linux']['monit']['alert_succeeded']                     = '#26C521'
default['linux']['monit']['slack_emoji']                         = ':hammer_and_wrench:'
default['linux']['monit']['notifies']                            = '<!channel>'
default['linux']['monit']['interval']                            = '30'
default['linux']['monit']['log']                                 = 'syslog'
default['linux']['monit']['slots']                               = '100'
default['linux']['monit']['http']['user']                        = 'admin'
default['linux']['monit']['http']['listen_address']              = 'localhost'
default['linux']['monit']['http']['listen_port']                 = '2812'

default['linux']['monit']['filesystems']                         = { 'root' => { 'label' => 'root',
                                                                                 'path' => '/',
                                                                                 'threshold' => '80%' },
                                                                     'boot' => { 'label' => 'boot',
                                                                                 'path' => '/boot',
                                                                                 'threshold' => '80%' },
                                                                     'home' => { 'label' => 'home',
                                                                                 'path' => '/home',
                                                                                 'threshold' => '80%' },
                                                                     'var' => { 'label' => 'var',
                                                                                'path' => '/var',
                                                                                'threshold' => '80%' },
                                                                     'tmp' => { 'label' => 'tmp',
                                                                                'path' => '/tmp',
                                                                                'threshold' => '80%' } }

default['linux']['openssh']['Protocol']                          = '2'
default['linux']['openssh']['Port']                              = '22'
default['linux']['openssh']['SyslogFacility']                    = 'AUTHPRIV'
default['linux']['openssh']['PermitRootLogin']                   = 'no'
default['linux']['openssh']['UsePrivilegeSeparation']            = 'sandbox'
default['linux']['openssh']['RhostsRSAAuthentication']           = 'no'
default['linux']['openssh']['HostbasedAuthentication']           = 'no'
default['linux']['openssh']['IgnoreRhosts']                      = 'yes'
default['linux']['openssh']['PermitEmptyPasswords']              = 'no'
default['linux']['openssh']['PasswordAuthentication']            = 'yes'
default['linux']['openssh']['ChallengeResponseAuthentication']   = 'no'
default['linux']['openssh']['GSSAPICleanupCredentials']          = 'yes'
default['linux']['openssh']['UsePAM']                            = 'yes'
default['linux']['openssh']['AcceptEnv']                         = 'LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL LANGUAGE XMODIFIERS'
default['linux']['openssh']['PermitTunnel']                      = 'no'
default['linux']['openssh']['ClientAliveInterval']               = '300'
default['linux']['openssh']['ClientAliveCountMax']               = '0'
default['linux']['openssh']['LoginGraceTime']                    = '60'
default['linux']['openssh']['PermitUserEnvironment']             = 'no'
default['linux']['openssh']['AllowGroups']                       = "#{node['linux']['authgroup']['administrators']} #{node['linux']['authgroup']['users']}"
default['linux']['openssh']['X11Forwarding']                     = 'no'
default['linux']['openssh']['Banner']                            = '/etc/issue'
default['linux']['openssh']['UseDNS']                            = 'no'
default['linux']['openssh']['Ciphers']                           = 'chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr'
default['linux']['openssh']['MACs']                              = 'hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com'
default['linux']['openssh']['StrictModes']                       = 'yes'
default['linux']['openssh']['Compression']                       = 'delayed'
default['linux']['openssh']['KerberosAuthentication']            = 'no'
default['linux']['openssh']['KbdInteractiveAuthentication']      = 'no'
default['linux']['openssh']['AllowAgentForwarding']              = 'yes'
default['linux']['openssh']['AllowTcpForwarding']                = 'no'
default['linux']['openssh']['Compression']                       = 'no'
default['linux']['openssh']['LogLevel']                          = 'VERBOSE'
default['linux']['openssh']['MaxSessions']                       = '2'
default['linux']['openssh']['TCPKeepAlive']                      = 'no'
default['linux']['openssh']['MaxAuthTries']                      = '2'
default['linux']['openssh']['MaxSessions']                       = '2'

default['linux']['postfix']['inet_interfaces']                   = 'localhost'
default['linux']['postfix']['inet_protocols']                    = 'ipv4'
default['linux']['postfix']['mydestination']                     = '$myhostname, localhost.$mydomain, localhost'
default['linux']['postfix']['relayhost']                         = '[smtp.gmail.com]:587'
default['linux']['postfix']['smtp_sasl_auth_enable']             = 'yes'
default['linux']['postfix']['smtp_sasl_password_maps']           = 'hash:/etc/postfix/sasl_passwd'
default['linux']['postfix']['smtp_sasl_security_options']        = 'noanonymous'
default['linux']['postfix']['smtp_sasl_mechanism_filter']        = 'plain'
default['linux']['postfix']['smtp_tls_CAfile']                   = '/etc/pki/tls/certs/ca-bundle.crt'
default['linux']['postfix']['smtp_use_tls']                      = 'yes'
default['linux']['postfix']['smtp_tls_security_level']           = 'encrypt'

default['linux']['firewall']['enable']                           = true
default['linux']['firewall']['ignoreexisting']                   = false
default['linux']['firewall']['ports']                            = {}
default['linux']['firewall']['services']                         = { 'ssh' => true }
default['linux']['firewall']['masquerade']                       = false

default['linux']['security']['secure_vartmp']                    = true
default['linux']['security']['secure_shm']                       = true
default['linux']['security']['secure_inittab']                   = true
default['linux']['security']['secure_init']                      = true

default['linux']['security']['remove_at_daemon']                 = false
default['linux']['security']['disable_modules']                  = true
default['linux']['security']['disable_ctrl_alt_delete']          = true
default['linux']['security']['remove_rsh_server']                = true
default['linux']['security']['remove_xinetd']                    = false
default['linux']['security']['remove_telnet_server']             = true
default['linux']['security']['remove_telnet']                    = true
default['linux']['security']['harden_as']                        = true
default['linux']['security']['enable_aide']                      = true
default['linux']['security']['enable_psacct']                    = true
default['linux']['security']['enable_usbguard']                  = true
default['linux']['security']['enable_arpwatch']                  = true

default['linux']['rsyslog']['rules']                             = { 'messages' => '*.info;mail.none;authpriv.none;cron.none                /var/log/messages',
                                                                     'secure' => 'authpriv.*                                              /var/log/secure',
                                                                     'maillog' => 'mail.*                                                  -/var/log/maillog',
                                                                     'cron' => 'cron.*                                                  /var/log/cron',
                                                                     'emerg' => '*.emerg                                                 *',
                                                                     'spooler' => 'uucp,news.crit                                          /var/log/spooler',
                                                                     'boot' => 'local7.*                                                /var/log/boot.log' }
default['linux']['rsyslog']['remotes']                           = {}
default['linux']['systemd']['journald']['forward_to_syslog'] = 'yes'

default['linux']['sysctl']                                       = { 'net.ipv4.conf.default.log_martians' => '1',
                                                                     'net.ipv4.conf.all.log_martians' => '1',
                                                                     'net.ipv4.conf.default.accept_redirects' => '0',
                                                                     'net.ipv4.conf.default.accept_source_route' => '0',
                                                                     'net.ipv4.conf.default.send_redirects' => '0',
                                                                     'net.ipv4.conf.all.accept_source_route' => '0',
                                                                     'net.ipv4.conf.all.forwarding' => '0',
                                                                     'net.ipv4.conf.all.rp_filter' => '1',
                                                                     'net.ipv4.icmp_ratelimit' => '100',
                                                                     'net.ipv4.icmp_ratemask' => '88089',
                                                                     'net.ipv4.tcp_timestamps' => '0',
                                                                     'net.ipv4.conf.all.arp_ignore' => '1',
                                                                     'net.ipv4.conf.all.arp_announce' => '2',
                                                                     'net.ipv4.tcp_rfc1337' => '1',
                                                                     'net.ipv4.conf.all.secure_redirects' => '0',
                                                                     'net.ipv4.conf.all.accept_redirects' => '0',
                                                                     'net.ipv4.conf.all.send_redirects' => '0',
                                                                     'net.ipv4.icmp_echo_ignore_broadcasts' => '1',
                                                                     'net.ipv4.tcp_max_syn_backlog' => '1280',
                                                                     'net.ipv4.tcp_syncookies' => '1',
                                                                     'net.ipv4.conf.default.secure_redirects' => '0',
                                                                     'net.ipv6.conf.default.accept_redirects' => '0',
                                                                     'net.ipv6.conf.all.accept_redirects' => '0',
                                                                     'net.ipv6.conf.default.accept_ra' => '0',
                                                                     'net.ipv6.conf.all.accept_ra' => '0',
                                                                     'vm.swappiness' => '0',
                                                                     'kernel.sysrq' => '0',
                                                                     'kernel.exec-shield' => '1',
                                                                     'fs.suid_dumpable' => '0',
                                                                     'kernel.randomize_va_space' => '2',
                                                                     'kernel.yama.ptrace_scope' => '1',
                                                                     'kernel.kptr_restrict' => '2',
                                                                     'kernel.dmesg_restrict' => '1' }

default['linux']['mounts']                                       = { 'root' => { 'device' => '/dev/sysvg/lv_root',
                                                                                 'mount_point' => '/',
                                                                                 'fs_type' => 'ext4',
                                                                                 'mount_options' => 'defaults',
                                                                                 'dump_frequency' => '1',
                                                                                 'fsck_pass_num' => '1',
                                                                                 'owner' => 'root',
                                                                                 'group' => 'root',
                                                                                 'mode' => '0755',
                                                                                  },
                                                                     'boot' => { 'device' => '/dev/sda1',
                                                                                 'mount_point' => '/boot',
                                                                                 'fs_type' => 'ext4',
                                                                                 'mount_options' => 'defaults,nodev,noexec,nosuid',
                                                                                 'dump_frequency' => '0',
                                                                                 'fsck_pass_num' => '0',
                                                                                 'owner' => 'root',
                                                                                 'group' => 'root',
                                                                                 'mode' => '0755',
                                                                                  },
                                                                     'home' => { 'device' => '/dev/sysvg/lv_home',
                                                                                 'mount_point' => '/home',
                                                                                 'fs_type' => 'ext4',
                                                                                 'mount_options' => 'defaults,nodev,nosuid,nodev,noexec',
                                                                                 'dump_frequency' => '1',
                                                                                 'fsck_pass_num' => '2',
                                                                                 'owner' => 'root',
                                                                                 'group' => 'root',
                                                                                 'mode' => '0755',
                                                                                  },
                                                                     'var' => { 'device' => '/dev/sysvg/lv_var',
                                                                                'mount_point' => '/var',
                                                                                'fs_type' => 'ext4',
                                                                                'mount_options' => 'defaults,nosuid,nodev',
                                                                                'dump_frequency' => '1',
                                                                                'fsck_pass_num' => '2',
                                                                                'owner' => 'root',
                                                                                'group' => 'root',
                                                                                'mode' => '0755',
                                                                                  },
                                                                     'tmp' => { 'device' => '/dev/sysvg/lv_tmp',
                                                                                'mount_point' => '/tmp',
                                                                                'fs_type' => 'ext4',
                                                                                'mount_options' => 'defaults,nosuid,nodev,noexec',
                                                                                'dump_frequency' => '1',
                                                                                'fsck_pass_num' => '2',
                                                                                'owner' => 'root',
                                                                                'group' => 'root',
                                                                                'mode' => '1777',
                                                                                  },
                                                                     'swap' => { 'device' => '/dev/sysvg/lv_swap',
                                                                                 'mount_point' => 'swap',
                                                                                 'fs_type' => 'swap',
                                                                                 'mount_options' => 'defaults',
                                                                                 'dump_frequency' => '0',
                                                                                 'fsck_pass_num' => '0',
                                                                                 'owner' => 'root',
                                                                                 'group' => 'root',
                                                                                 'mode' => '0755',
                                                                                  },
                                                                     'vartmp' => { 'device' => '/tmp',
                                                                                   'mount_point' => '/var/tmp',
                                                                                   'fs_type' => 'none',
                                                                                   'mount_options' => 'bind,nosuid,nodev,noexec',
                                                                                   'dump_frequency' => '0',
                                                                                   'fsck_pass_num' => '0',
                                                                                   'owner' => 'root',
                                                                                   'group' => 'root',
                                                                                   'mode' => '1777',
                                                                                  },
                                                                     'shm' => { 'device' => 'tmpfs',
                                                                                'mount_point' => '/dev/shm',
                                                                                'fs_type' => 'tmpfs',
                                                                                'mount_options' => 'defaults,nosuid,nodev,noexec',
                                                                                'dump_frequency' => '0',
                                                                                'fsck_pass_num' => '0',
                                                                                'owner' => 'root',
                                                                                'group' => 'root',
                                                                                'mode' => '1777',
                                                                                  },
                                                                     'devpts' => { 'device' => 'devpts',
                                                                                   'mount_point' => '/dev/pts',
                                                                                   'fs_type' => 'devpts',
                                                                                   'mount_options' => 'gid=5,mode=620',
                                                                                   'dump_frequency' => '0',
                                                                                   'fsck_pass_num' => '0',
                                                                                   'owner' => 'root',
                                                                                   'group' => 'root',
                                                                                   'mode' => '0755',
                                                                                  },
                                                                     'sysfs' => { 'device' => 'sysfs',
                                                                                  'mount_point' => '/sys',
                                                                                  'fs_type' => 'sysfs',
                                                                                  'mount_options' => 'defaults,nosuid,nodev,noexec',
                                                                                  'dump_frequency' => '0',
                                                                                  'fsck_pass_num' => '0',
                                                                                  'owner' => 'root',
                                                                                  'group' => 'root',
                                                                                  'mode' => '0555',
                                                                                  },
                                                                     'proc' => { 'device' => 'proc',
                                                                                 'mount_point' => '/proc',
                                                                                 'fs_type' => 'proc',
                                                                                 'mount_options' => 'defaults,nosuid,nodev,noexec,hidepid=2',
                                                                                 'dump_frequency' => '0',
                                                                                 'fsck_pass_num' => '0',
                                                                                 'owner' => 'root',
                                                                                 'group' => 'root',
                                                                                 'mode' => '0555',
                                                                                  },
                                                                   }

default['linux']['yum']['local_mirror']                          = "mirror.#{node['linux']['domain_name']}"

default['linux']['yum']['package_mirrors']['CentOS_7_x86_64']    = { 'base' => {  'name' => 'CentOS-$releasever - Base',
                                                                                  'baseurl' => "https://#{node['linux']['yum']['local_mirror']}/mirrors/centos/7/os/x86_64",
                                                                                  'gpgcheck' => '1',
                                                                                  'enabled' => '1',
                                                                                  'gpgkey' => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' },
                                                                     'updates' => {  'name' => 'CentOS-$releasever - Updates',
                                                                                     'baseurl' => "https://#{node['linux']['yum']['local_mirror']}/mirrors/centos/7/updates/x86_64",
                                                                                     'gpgcheck' => '1',
                                                                                     'enabled' => '1',
                                                                                     'gpgkey' => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' },
                                                                     'extras' => { 'name' => 'CentOS-$releasever - Extras',
                                                                                   'baseurl' => "https://#{node['linux']['yum']['local_mirror']}/mirrors/centos/7/extras/x86_64",
                                                                                   'gpgcheck' => '1',
                                                                                   'enabled' => '1',
                                                                                   'gpgkey' => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' },
                                                                     'epel' => { 'name' => 'CentOS-$releasever - EPEL',
                                                                                 'baseurl' => "https://#{node['linux']['yum']['local_mirror']}/mirrors/epel/7/x86_64/",
                                                                                 'gpgcheck' => '1',
                                                                                 'enabled' => '1',
                                                                                 'gpgkey' => "https://#{node['linux']['yum']['local_mirror']}/mirrors/epel/RPM-GPG-KEY-EPEL-7" } }

default['linux']['yum']['local_repositories']                    = { 'stable' => { 'name' => 'Stable Repository',
                                                                                   'baseurl' => "https://#{node['linux']['yum']['local_mirror']}/mirrors/local/#{node['platform_version'][0]}/STABLE/RPMS",
                                                                                   'gpgcheck' => '1',
                                                                                   'enabled' => '1',
                                                                                   'gpgkey' => "https://#{node['linux']['yum']['local_mirror']}/mirrors/local/RPM-GPG-KEY-LOCAL-#{node['platform_version'][0]}",
                                                                                   'metadata_expire' => '300' } }
