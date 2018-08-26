###
### Cookbook:: chef
### Recipe:: configure_reporting
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

unless node['chef']['install_reporting'] == true && node['chef']['accept_reporting_license'] == true
  return
end

###
### The encrypted payload password is stored in credentials -> passwords
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

###
### passfile is used to encrypt and decrypt file based Chef secrets.
###

passfile = Random.rand(99999999) * Random.rand(99999999) * Random.rand(99999999)
file "#{Chef::Config[:file_cache_path]}/.#{passfile}" do
  owner 'root'
  group 'root'
  mode 0600
  content passwords['bootstrap_passphrase']
  backup false
  sensitive true
  action :nothing
end

execute 'reporting-reconfigure' do
  command "opscode-reporting-ctl reconfigure --accept-license"
  sensitive node['chef']['runtime']['sensitivity']
  action :nothing
end

reporting_version_test = `rpm -q opscode-reporting --qf "%{VERSION}" 2>/dev/null | awk '/^[0-9]/ {printf $1}'`
install_file = `curl "#{node['chef']['reporting_url']}/#{node['platform_version'][0]}/" 2>/dev/null | grep "opscode-reporting.*.x86_64.rpm" | sed -s -e 's/^.*href="//' -e 's/".*$//' -e 's/<[^>]*>//g' | head -n 1 | awk '{printf $1}'`
remote_file "#{Chef::Config['file_cache_path']}/#{install_file}" do
  source "#{node['chef']['reporting_url']}#{node['platform_version'][0]}/#{install_file}"
  owner 'root'
  group 'root'
  mode 0640
  action :create
  sensitive node['chef']['runtime']['sensitivity']
  only_if { node['chef']['install_reporting'] == true }
  only_if { node['chef']['install_from_source'] == true }
  not_if { reporting_version_test == node['chef']['reporting_version'] }
end

rpm_package "opscode-reporting" do
  allow_downgrade true
  source "#{Chef::Config['file_cache_path']}/#{install_file}"
  action :install
  notifies :run, 'execute[chef-reconfigure]', :immediately
  notifies :run, 'execute[reporting-reconfigure]', :immediately
  only_if { node['chef']['install_reporting'] == true }
  only_if { node['chef']['install_from_source'] == true }
  not_if { reporting_version_test == node['chef']['reporting_version'] }
end

yum_package [ "opscode-reporting = #{node['chef']['reporting_version']}" ] do
  allow_downgrade true
  action :install
  flush_cache [ :before ]
  notifies :run, 'execute[chef-reconfigure]', :immediately
  notifies :run, 'execute[reporting-reconfigure]', :immediately
  only_if { node['chef']['install_reporting'] == true }
  only_if { node['chef']['install_from_source'] == false }
  not_if { reporting_version_test == node['chef']['reporting_version'] }
end
