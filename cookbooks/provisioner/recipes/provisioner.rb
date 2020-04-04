###
### Cookbook Name:: provisioner
### Recipe:: provisioner
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

require 'fileutils'

yum_package [ 'httpd',
              'mod_security',
              'mod_ssl',
              'dhcp',
              'bind',
              'xinetd',
              'tftp-server',
              'hardlink',
              'pykickstart',
              'cobbler'] do
  action :install
end

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

cookbook_file '/etc/httpd/conf.d/get.conf' do
  source 'etc/httpd/conf.d/get.conf'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[httpd]', :immediately
end

###
### Configure the http server to use the SSL certificates from Let's Encrypt
###

if node['linux']['dns']['mechanism'] == 'zonomi' && node['provisioner']['ssl']['use_acme'] == true
  node.default['provisioner']['httpd']['ssl_certificate'] = '/etc/pki/tls/certs/localhost.crt'
  node.default['provisioner']['httpd']['ssl_certificate_key'] = '/etc/pki/tls/private/localhost.key'
end

###
### Does my certificate exist, or is it within the renewal window?
###

currentdate = `date '+%s'`.chomp

certexpiration = if File.exist?("/etc/opscode/#{node['fqdn']}.crt")
                   `date -d "$(/usr/bin/openssl x509 -enddate -noout -in #{node['chef']['server_attributes']['nginx']['ssl_certificate']} | sed -e 's#notAfter=##')" '+%s'`.chomp
                 else
                   currentdate
                 end

certdaysleft = (certexpiration.to_i - currentdate.to_i) / 86400
if certdaysleft < node['chef']['ssl']['renewal_day'].to_i
  renew_now = true
end

notification = "Renewing my SSL certificate @ #{certdaysleft} days left."
execute 'Renewal notification' do
  command "notify \"#{node['linux']['slack_channel']}\" \"#{node['provisioner']['replicator_emoji']}\" \"#{node['linux']['api_path']}\"  \"#{notification}\""
  action :run
  only_if { renew_now == true }
end

###
### Deconstruct the names to pass to acme.sh
###

certnames = ''
node['provisioner']['ssl']['hostnames'].each do |_type, value|
  certnames = certnames + '-d ' + value + ' '
end

yum_package [ 'git' ] do
  action :install
  only_if { node['linux']['dns']['mechanism'] == 'zonomi' }
  only_if { node['provisioner']['ssl']['use_acme'] == true }
  only_if { renew_now == true }
end

git "#{Chef::Config[:file_cache_path]}/acme.sh" do
  repository node['provisioner']['ssl']['acme_giturl']
  reference 'master'
  action :sync
  sensitive node['provisioner']['runtime']['sensitivity']
  not_if { Dir.exist?("#{Chef::Config['file_cache_path']}/acme.sh") }
  only_if { node['linux']['dns']['mechanism'] == 'zonomi' }
  only_if { node['provisioner']['ssl']['use_acme'] == true }
  only_if { renew_now == true }
end

execute 'Creating or renewing certificate' do
  command "ZM_Key=\"#{passwords['zonomi_api']}\" bash acme.sh --force --issue --dns dns_zonomi #{certnames} --fullchain-file #{node['provisioner']['httpd']['ssl_certificate']} --key-file #{node['provisioner']['httpd']['ssl_certificate_key']}; \
           rm -rf /tmp/acme"
  cwd "#{Chef::Config['file_cache_path']}/acme.sh"
  action :run
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[httpd]', :delayed
  only_if { node['linux']['dns']['mechanism'] == 'zonomi' }
  only_if { node['provisioner']['ssl']['use_acme'] == true }
  only_if { renew_now == true }
end

template '/etc/httpd/conf.d/ssl.conf' do
  source 'etc/httpd/conf.d/ssl.conf.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[httpd]', :delayed
  only_if { node['provisioner']['ssl']['enabled'] == true }
end

template '/etc/httpd/conf.d/redirect.conf' do
  source 'etc/httpd/conf.d/redirect.conf.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[httpd]', :delayed
  only_if { node['provisioner']['ssl']['enabled'] == true }
end

cookbook_file '/etc/xinetd.d/tftp' do
  source 'etc/xinetd.d/tftp'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[xinetd]', :immediately
end

directory node['provisioner']['name_gen_path'] do
  owner 'apache'
  group 'apache'
  mode 0750
  action :create
end

file "#{node['provisioner']['name_gen_path']}/.token" do
  owner 'apache'
  group 'apache'
  mode 0640
  content node['provisioner']['hostname_auth_token']
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/www/cgi-bin/hostname' do
  source 'var/www/cgi-bin/hostname.erb'
  owner 'root'
  group 'root'
  mode 0755
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/etc/cobbler/dhcp.template' do
  source 'etc/cobbler/dhcp.template.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[cobblerd]', :immediate
end

template '/etc/cobbler/named.template' do
  source 'etc/cobbler/named.template.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[cobblerd]', :immediate
end

template '/etc/cobbler/zone.template' do
  source 'etc/cobbler/zone.template.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[cobblerd]', :immediate
end

template '/etc/cobbler/named.template' do
  source 'etc/cobbler/named.template.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[cobblerd]', :immediate
end

template '/etc/cobbler/settings' do
  source 'etc/cobbler/settings.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[cobblerd]', :immediate
  variables(
    password: passwords['cobbler']
  )
end

template '/etc/cobbler/pxe/pxedefault.template' do
  source 'etc/cobbler/pxe/pxedefault.template.erb'
  owner 'root'
  group 'root'
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[cobblerd]', :immediate
  variables(
    root_hash: passwords['root_hash']
  )
end

bash 'Download the cobbler loaders' do
  code <<-EOF
    (systemctl status cobblerd | grep "Active: active" >/dev/null 2>&1) || systemctl start cobblerd
    cobbler get-loaders
  EOF
  sensitive node['provisioner']['runtime']['sensitivity']
  not_if { File.exist? '/var/lib/cobbler/loaders/README' }
end

template '/var/lib/cobbler/kickstarts/CentOS-7-x86_64' do
  source 'var/lib/cobbler/kickstarts/CentOS-7-x86_64.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  variables(
    rootpw: passwords['root_hash']
  )
end

template '/var/lib/cobbler/snippets/base-build-notice' do
  source 'var/lib/cobbler/snippets/base-build-notice.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/base-chef' do
  source 'var/lib/cobbler/snippets/base-chef.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  variables(
    chefpw: passwords['bootstrap_passphrase']
  )
end

template '/var/lib/cobbler/snippets/base-complete' do
  source 'var/lib/cobbler/snippets/base-complete.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/base-hostname' do
  source 'var/lib/cobbler/snippets/base-hostname.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/base-notify' do
  source 'var/lib/cobbler/snippets/base-notify.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/base-packages' do
  source 'var/lib/cobbler/snippets/base-packages.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/base-boot' do
  source 'var/lib/cobbler/snippets/base-boot.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/base-partitions' do
  source 'var/lib/cobbler/snippets/base-partitions.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

node['linux']['yum']['package_mirrors'].each do |id, _data|
  mirror = id
  template "/var/lib/cobbler/snippets/base-repos-centos-#{mirror}" do
    source 'var/lib/cobbler/snippets/base-repos-centos.erb'
    owner 'root'
    group 'root'
    mode 0640
    action :create
    sensitive node['provisioner']['runtime']['sensitivity']
    variables(
      mirror: mirror
    )
  end
end

template '/var/lib/cobbler/snippets/base-resolver' do
  source 'var/lib/cobbler/snippets/base-resolver.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/base-rootpw' do
  source 'var/lib/cobbler/snippets/base-rootpw.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  variables(
    rootpw: passwords['root_hash']
  )
end

template '/var/lib/cobbler/snippets/kickstart_start' do
  source 'var/lib/cobbler/snippets/kickstart_start.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/kickstart_done' do
  source 'var/lib/cobbler/snippets/kickstart_done.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/var/lib/cobbler/snippets/cobbler_register' do
  source 'var/lib/cobbler/snippets/cobbler_register.erb'
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

node['provisioner']['cobbler']['distros'].each do |distro, distro_metadata|
  directory "#{node['provisioner']['cobbler']['bootimage_path']}/#{distro}/pxeboot" do
    owner 'apache'
    group 'apache'
    mode 0644
    action :create
    recursive true
    sensitive node['provisioner']['runtime']['sensitivity']
  end

  remote_file distro_metadata['kernel'] do
    source "#{node['provisioner']['cobbler']['repos'][distro.to_s]['mirror']}/images/pxeboot/vmlinuz" # ~FC002
    owner 'apache'
    group 'apache'
    mode 0644
    action :create
    sensitive node['provisioner']['runtime']['sensitivity']
  end

  remote_file distro_metadata['initrd'] do
    source "#{node['provisioner']['cobbler']['repos'][distro.to_s]['mirror']}/images/pxeboot/initrd.img" # ~FC002
    owner 'apache'
    group 'apache'
    mode 0644
    action :create
    sensitive node['provisioner']['runtime']['sensitivity']
  end
end

node['provisioner']['cobbler']['distros'].each do |id, parameters|
  distro_list = `cobbler distro list 2>&1 | awk '{print $1}'`
  add_command = ''
  next if distro_list =~ /#{id}/i
  parameters.each do |key, value|
    unless key == 'repos'
      add_command += " --#{key} #{value}"
    end
  end
  bash "Adding the #{id} distro to cobbler" do
    code <<-EOF
        cobbler distro add #{add_command}
    EOF
    sensitive node['provisioner']['runtime']['sensitivity']
  end
end

node['provisioner']['cobbler']['profiles'].each do |id, parameters|
  profile_list = `cobbler profile list 2>&1 | awk '{print $1}'`
  add_command = ''
  next if profile_list =~ /#{id}/i
  parameters.each do |key, value|
    add_command += " --#{key} #{value}"
  end
  bash "Adding the #{id} profile to cobbler" do
    code <<-EOF
        cobbler profile add #{add_command}
    EOF
    sensitive node['provisioner']['runtime']['sensitivity']
  end
end

node['provisioner']['cobbler']['systems'].each do |id, parameters|
  system_list = `cobbler system list 2>&1 | awk '{print $1}'`
  add_command = ''
  next if system_list =~ /#{id}/i
  parameters.each do |key, value|
    add_command += " --#{key} #{value}"
  end
  bash "Adding the #{id} system to cobbler" do
    code <<-EOF
        cobbler system add #{add_command}
    EOF
    sensitive node['provisioner']['runtime']['sensitivity']
  end
end

default_system = `cobbler system dumpvars --name default | awk '/profile_name/ {printf $3}' 2>/dev/null ||:`

bash 'Configure the cobbler default profile' do
  code <<-EOF
    cobbler system remove --name default 2>/dev/null
    cobbler system add --name default --profile #{node['linux']['cobbler']['profile']}
  EOF
  not_if { default_system == node['linux']['cobbler']['profile'] }
end

bash 'Execute Cobbler Sync' do
  code <<-EOF
    cobbler sync
  EOF
  action :run
  sensitive node['provisioner']['runtime']['sensitivity']
  subscribes :run, 'file[/etc/cobbler/dhcp.template]', :delayed
  subscribes :run, 'template[/etc/cobbler/named.template]', :delayed
end

service 'httpd' do
  supports status: true, restart: true
  action [ :enable, :start ]
end

service 'xinetd' do
  supports status: true, restart: true
  action [ :enable, :start ]
end

service 'named' do
  supports status: true, restart: true
  action [ :enable, :start ]
  only_if { node['provisioner']['manage_dns'] == '1' }
end

service 'dhcpd' do
  supports status: true, restart: true
  action [ :enable, :start ]
end

service 'cobblerd' do
  supports status: true, restart: true
  action [ :enable, :start ]
end

template '/usr/bin/decom-watch' do
  source 'usr/bin/decom-watch.erb'
  owner 'root'
  group 'bin'
  mode '0755'
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/etc/cron.d/decom-watch' do
  source 'etc/cron.d/decom-watch.erb'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

template '/etc/monit.d/httpd' do
  source 'etc/monit.d/httpd.erb'
  owner 'root'
  group 'root'
  mode 0600
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

template '/etc/monit.d/xinetd' do
  source 'etc/monit.d/xinetd.erb'
  owner 'root'
  group 'root'
  mode 0600
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

template '/etc/monit.d/httpd' do
  source 'etc/monit.d/httpd.erb'
  owner 'root'
  group 'root'
  mode 0600
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
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

###
###  Tag myself to identify my function
###

tag('provisioner')

### Send a notification that this system is now a provisioner
notification = 'FYI.. I am now configured as a VM provisioner.'
bash notification do
  code <<-EOF
    notify "#{node['linux']['slack_channel']}" "#{node['provisioner']['kickstart_emoji']}" "#{node['linux']['api_path']}" "#{notification}"
    touch /var/.provisioner
  EOF
  only_if { node['linux']['slack_enabled'] == true }
  not_if { File.exist? '/var/.provisioner' }
end
