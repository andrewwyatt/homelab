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

###
### Install the packages needed to build RPMs.
###

yum_package [
              'mock',
              'rpm-build',
              'xinetd',
              'rsync',
              'createrepo',
              'httpd',
              'expect' ] do
  action :install
end

###
### EL7 needs rpm-sign which is built into rpmbuild in EL6.
###

yum_package 'rpm-sign' do
  action :install
  only_if { node['platform_version'] =~ /^7/ }
end

###
### Create the group, create the user in the group.
###

group node['provisioner']['user'] do
  action :create
end

user node['provisioner']['user'] do
  gid node['provisioner']['user']
  shell node['provisioner']['shell']
  home node['provisioner']['path']
  comment "Package Builder"
  manage_home true
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

group node['provisioner']['package_group'] do
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

package_members = String.new
node['provisioner']['package_members'].each do |package_member|
  if package_members =~ /[A-z]/
    package_members = package_members + "," + package_member
  else
    package_members = package_member
  end
end

group node['provisioner']['package_group'] do
  action :modify
  members package_members
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### Configure the build account with sudo permissions.
###

node.normal['linux']['sudoers']['properties'] = {node['provisioner']['user'] => "#{node['provisioner']['user']} ALL=(ALL) NOPASSWD:ALL" }

group "mock" do
  action :modify
  members node['provisioner']['user']
  append true
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### Create the directories that will be used by the build software
###

directory node['provisioner']['path'] do
  owner node['provisioner']['user']
  group node['provisioner']['user']
  mode "0700"
  action :create
end

directory "#{node['provisioner']['path']}/bin" do
  owner node['provisioner']['user']
  group node['provisioner']['user']
  mode "0700"
  action :create
end

directory "#{node['provisioner']['path']}/etc" do
  owner node['provisioner']['user']
  group node['provisioner']['user']
  mode "0700"
  action :create
end

directory node['provisioner']['buildpath'] do
  owner "root"
  group "mock"
  mode "0775"
  action :create
end

directory "#{node['provisioner']['buildpath']}/mock" do
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode "0775"
  action :create
end

###
### Build the repository that will host the packages.
###

directory node['provisioner']['baserepopath'] do
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode "0775"
  recursive true
  action :create
end

directory "#{node['provisioner']['baserepopath']}/UPLOADS" do
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode "0775"
  action :create
end

link "#{node['provisioner']['path']}/UPLOADS" do
  to "#{node['provisioner']['baserepopath']}/UPLOADS"
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode 0644
  action :create
end

###
### This tool builds the packages.
###

cookbook_file "#{node['provisioner']['path']}/bin/build_package.sh" do
  source "bin/build_package.sh"
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode "0755"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### This tool will import previously built packages, resigning them with our keys.
###

cookbook_file "#{node['provisioner']['path']}/bin/import_package.sh" do
  source "bin/import_package.sh"
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode "0755"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### This tool watches the directories and updates the repository metadata when changed.
###

cookbook_file "#{node['provisioner']['path']}/bin/watch_repos.sh" do
  source "bin/watch_repos.sh"
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode "0755"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### This tool monitors the upload directories, and triggers build or import events.
###

cookbook_file "#{node['provisioner']['path']}/bin/watch_uploads.sh" do
  source "bin/watch_uploads.sh"
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode "0755"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### Sets up a read only mirror to be consumed by the mirror hosts.
###

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

template "/etc/rsyncd.d/packager.conf" do
  source "etc/rsyncd.d/template.conf.erb"
  owner "root"
  group "bin"
  mode "0644"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  variables({
    :repository_name      => node['provisioner']['packager']['rsync']['repository_name'],
    :repository_path      => node['provisioner']['packager']['rsync']['repository_path'],
    :repository_comment   => node['provisioner']['packager']['rsync']['repository_comment']
  })
end


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

###
### This configuration file sets up mock to build packages for the platform.
###

node['provisioner']['repositories'].each do |key,repository|
  template "/etc/mock/epel-#{node['platform_version'][0]}-x86_64-#{repository}.cfg" do
    source "etc/epel-#{node['platform_version'][0]}-x86_64.cfg.erb"
    owner "root"
    group "bin"
    mode "0644"
    action :create
    sensitive node['provisioner']['runtime']['sensitivity']
    variables({
      :repository  => repository,
      :mirror      => "CentOS_#{node['platform_version'][0]}_x86_64"
    })
  end

end

###
### LADIES AND GENTLEMAN START YOUR BUILDERS
###

template "/etc/cron.d/builder" do
  source "etc/cron.d/builder.erb"
  owner "root"
  group "bin"
  mode "0644"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
end

directory "#{node['provisioner']['path']}/signing_keys" do
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode "0700"
  action :create
end

build_properties = data_bag_item('credentials', node['provisioner']['user'], IO.read(Chef::Config['encrypted_data_bag_secret']))

###
### .rpmmacros is used by rpmsign to identify what key to use for signing.
###

rpmmacros = build_properties['rpmmacros']
file "#{node['provisioner']['path']}/.rpmmacros" do
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode  "0700"
  content rpmmacros
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### Configures the platform builder service parameters
###

template "#{node['provisioner']['path']}/etc/builder.conf" do
  source "etc/builder.conf.erb"
  owner node['provisioner']['user']
  group node['provisioner']['user']
  mode "0700"
  action :create
  sensitive node['provisioner']['runtime']['sensitivity']
  variables({
    :signkey   => build_properties['signing_passphrase'],
  })
end

###
### We need the private key for signing.
###

private_key = build_properties['private_key']
file "#{node['provisioner']['path']}/signing_keys/#{node['provisioner']['user']}.pvt" do
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode  "0600"
  content private_key
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### We need the public key for the repository consumers.
###

public_key = build_properties['public_key']
file "#{node['provisioner']['reporoot']}/#{node['provisioner']['pubkey']}" do
  owner node['provisioner']['user']
  group node['provisioner']['package_group']
  mode  "0644"
  content public_key
  sensitive node['provisioner']['runtime']['sensitivity']
end

###
### Configure the signing key.
###

gpgid = build_properties['gpgid']
bash "Install GPG key" do
  code "su #{node['provisioner']['user']} -l -c \"gpg --import #{node['provisioner']['path']}/signing_keys/#{node['provisioner']['user']}.pvt\""
  sensitive node['provisioner']['runtime']['sensitivity']
  not_if "su #{node['provisioner']['user']} -l -c \"gpg --list-keys | grep #{gpgid}\""
end

###
### Configures all of the locally defined repositories for use by the build service.
###

node['provisioner']['repositories'].each do |key,repository|
  bash "Create initial [#{repository}] RPM repository." do
    code <<-EOF
      if [ ! -d "#{node['provisioner']['baserepopath']}/#{repository}/RPMS" ]
      then
        mkdir -p #{node['provisioner']['baserepopath']}/#{repository}/RPMS
        chmod -R 775 #{node['provisioner']['user']}:#{node['provisioner']['package_group']} #{node['provisioner']['baserepopath']}/#{repository}
        cd #{node['provisioner']['baserepopath']}/#{repository}/RPMS
        createrepo --update .
        chown -R "#{node['provisioner']['user']}":"#{node['provisioner']['package_group']}" #{node['provisioner']['baserepopath']}/#{repository}
      fi
      if [ ! -d "#{node['provisioner']['baserepopath']}/#{repository}/SRPMS" ]
      then
        mkdir -p #{node['provisioner']['baserepopath']}/#{repository}/SRPMS
        chmod -R 775 #{node['provisioner']['user']}:#{node['provisioner']['package_group']} #{node['provisioner']['baserepopath']}/#{repository}
        cd #{node['provisioner']['baserepopath']}/#{repository}/SRPMS
        createrepo --update .
        chown -R "#{node['provisioner']['user']}":"#{node['provisioner']['package_group']}" #{node['provisioner']['baserepopath']}/#{repository}
      fi
    EOF
    sensitive node['provisioner']['runtime']['sensitivity']
  end
end

###
### Removes the Apache welcome to allow the repository to be browseable.
###

file "/etc/httpd/conf.d/welcome.conf" do
  action :delete
  notifies :restart, "service[httpd]", :immediately
end

###
### Link the repository to the web root.
###

link "#{node['provisioner']['webroot']}/#{node['provisioner']['linkname']}" do
  to node['provisioner']['reporoot']
  owner 'root'
  group 'root'
  mode 0755
  action :create
  only_if { ::File.directory?(node['provisioner']['webroot']) == true }
end

service "httpd" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

###
###  Tag myself to identify my function and my cname
###

tag('builder')
tag(node['provisioner']['builder_cname'])


###
### Send a notification that this system is now a package builder
###

notification = 'FYI.. I am now configured as an RPM builder.'
bash notification do
  code <<-EOF
    notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['provisioner']['builder_emoji']}" "#{node['linux']['api_path']}" "#{notification}"
    touch /var/.builder
  EOF
  not_if { File.exists? '/var/.builder' }
  only_if { node['linux']['slack_enabled'] == true }
end
