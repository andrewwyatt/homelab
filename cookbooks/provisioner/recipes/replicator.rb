###
### Cookbook Name:: builder
### Recipe:: default
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

yum_package [ 'rsync',
              'xinetd',
              'httpd',
              'mod_security',
              'mod_ssl' ] do
  action :install
end

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

directory "/opt/provisioner" do
  owner "root"
  group "bin"
  mode "0750"
  action :create
end

directory "/opt/provisioner/bin" do
  owner "root"
  group "bin"
  mode "0750"
  action :create
end

  directory node['provisioner']['mirrorroot'] do
    owner "root"
    group "bin"
    mode "0755"
    action :create
  end

node['provisioner']['mirrors'].each do | mirror, mirror_data |

  template "/opt/provisioner/bin/mirror_#{mirror_data['name']}.sh" do
    source "bin/mirror.sh.erb"
    owner "root"
    group "bin"
    mode "0755"
    action :create
    sensitive node['provisioner']['runtime']['sensitivity']
    variables({
      name:         mirror_data['name'],
      url:          mirror_data['url'],
      mirror_path:  mirror_data['mirror_path']
    })
    only_if { mirror_data['enabled'] == true }
  end

  file "/opt/provisioner/bin/mirror_#{mirror_data['name']}.sh" do
    action :delete
    only_if { mirror_data['enabled'] == false }
  end

  template "/etc/cron.d/mirror_#{mirror_data['name']}" do
    source "etc/cron.d/mirror.erb"
    owner "root"
    group "root"
    mode "0644"
    action :create
    sensitive node['provisioner']['runtime']['sensitivity']
    variables({
      name:            mirror_data['name'],
      url:             mirror_data['url'],
      mirror_path:     mirror_data['mirror_path'],
      mirror_schedule: mirror_data['mirror_schedule']
    })
    only_if { mirror_data['enabled'] == true }
  end

  directory mirror_data['gpg_key_path'] do
    owner "root"
    group "bin"
    mode "0755"
    action :create
  end

  remote_file "#{mirror_data['gpg_key_path']}/#{mirror_data['gpg_key_name']}" do
    source "#{mirror_data['gpg_key_url']}/#{mirror_data['gpg_key_name']}"
    owner "root"
    group "bin"
    mode "0644"
    action :create
    sensitive node['provisioner']['runtime']['sensitivity']
    not_if { (defined?(mirror_data['gpg_key_path'])).empty? == true }
    not_if { (defined?(mirror_data['gpg_key_url'])).empty? == true }
    not_if { (defined?(mirror_data['gpg_key_name'])).empty? == true }
    not_if { mirror_data['enabled'] == false }
  end


  file "/etc/cron.d/mirror_#{mirror_data['name']}" do
    action :delete
    only_if { mirror_data['enabled'] == false }
  end

end

directory "/etc/rsyncd.d" do
  owner 'root'
  group 'root'
  mode "0775"
  action :create
end

template "/etc/rsyncd.conf" do
  source "etc/rsyncd.conf.erb"
  owner "root"
  group "bin"
  mode "0644"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  variables({
    :pid_file             => node['provisioner']['common']['rsync']['pid_file'],
    :uid                  => node['provisioner']['common']['rsync']['uid'],
    :gid                  => node['provisioner']['common']['rsync']['gid'],
    :use_chroot           => node['provisioner']['common']['rsync']['use_chroot'],
    :read_only            => node['provisioner']['common']['rsync']['read_only'],
    :hosts_allow          => node['provisioner']['common']['rsync']['hosts_allow'],
    :hosts_deny           => node['provisioner']['common']['rsync']['hosts_deny'],
    :max_connections      => node['provisioner']['common']['rsync']['max_connections'],
    :log_format           => node['provisioner']['common']['rsync']['log_format'],
    :syslog_facility      => node['provisioner']['common']['rsync']['syslog_facility'],
    :timeout              => node['provisioner']['common']['rsync']['timeout'],
  })
end

template "/etc/rsyncd.d/replicator.conf" do
  source "etc/rsyncd.d/template.conf.erb"
  owner "root"
  group "bin"
  mode "0644"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  variables({
    :repository_name      => node['provisioner']['replicator']['rsync']['repository_name'],
    :repository_path      => node['provisioner']['replicator']['rsync']['repository_path'],
    :repository_comment   => node['provisioner']['replicator']['rsync']['repository_comment']
  })
end

###
### Need to work this out for scenarios where the use case is single instance.
###
template "/etc/xinetd.d/rsync" do
  source "etc/xinetd.d/rsync.erb"
  owner "root"
  group "bin"
  mode "0644"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, "service[xinetd]", :immediately
end

service "xinetd" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

file "/etc/httpd/conf.d/welcome.conf" do
  action :delete
  notifies :restart, "service[httpd]", :immediately
end

###
### Configure the http server to use the SSL certificates from Let's Encrypt
###

if node['linux']['dns']['mechanism'] == 'zonomi' && node['provisioner']['ssl']['use_acme'] == true
  node.default['provisioner']['httpd']['ssl_certificate'] = "/etc/pki/tls/certs/localhost.crt"
  node.default['provisioner']['httpd']['ssl_certificate_key'] = "/etc/pki/tls/private/localhost.key"
end

###
### Does my certificate exist, or is it within the renewal window?
###

currentdate = Date.today.to_time.to_i

if File.exists?(node['provisioner']['httpd']['ssl_certificate'])
  certexpiration = `date -d "$(openssl x509 -enddate -noout -in #{node['provisioner']['httpd']['ssl_certificate']} | sed -e 's#notAfter=##')" '+%s'`
else
  certexpiration = currentdate
end

certdaysleft = (certexpiration.to_i - currentdate.to_i)
if certdaysleft < node['provisioner']['ssl']['renewal_day'].to_i
  renew_now = true
end

###
### Deconstruct the names to pass to acme.sh
###

certnames = String.new
node['provisioner']['ssl']['hostnames'].each do | type,value |
   certnames = certnames + "-d " + value + " "
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
  not_if { Dir.exists?("#{Chef::Config['file_cache_path']}/acme.sh")}
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

template "/etc/httpd/conf.d/ssl.conf" do
  source "etc/httpd/conf.d/ssl.conf.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[httpd]', :delayed
  only_if { node['provisioner']['ssl']['enabled'] == true }
end

template "/etc/httpd/conf.d/redirect.conf" do
  source "etc/httpd/conf.d/redirect.conf.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[httpd]', :delayed
  only_if { node['provisioner']['ssl']['enabled'] == true }
end

service "httpd" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

template "/etc/monit.d/httpd" do
  source "etc/monit.d/httpd.erb"
  owner "root"
  group "root"
  mode 0600
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  notifies :restart, 'service[monit]', :delayed
  only_if { node['linux']['monit']['enabled'] == true }
end

template "/etc/monit.d/xinetd" do
  source "etc/monit.d/xinetd.erb"
  owner "root"
  group "root"
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

tag('mirror')

### Send a notification that this system is now an upstream mirror
notification = 'FYI.. I am now configured as an upstream mirror.'
bash notification do
  code <<-EOF
    notify "#{node['linux']['slack_channel']}" "#{node['provisioner']['replicator_emoji']}" "#{node['linux']['api_path']}" "#{notification}"
    touch /var/.mirror
  EOF
  not_if { File.exists? '/var/.mirror' }
  only_if { node['linux']['slack_enabled'] == true }
end
