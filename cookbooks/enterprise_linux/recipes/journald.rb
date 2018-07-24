###
### Cookbook Name:: enterprise_linux
### Recipe:: journald
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

template '/etc/systemd/journald.conf' do
  source "etc/systemd/journald.conf.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
	sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, "service[systemd-journald]", :immediately
  notifies :restart, "service[rsyslog]", :delayed
	only_if { node['platform_version'] =~ /^7/ }
end

service "systemd-journald" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
	only_if { node['platform_version'] =~ /^7/ }
end

service "rsyslog" do
   supports :status => true, :restart => true
   action [ :enable, :start ]
	 only_if { node['platform_version'] =~ /^7/ }
 end
