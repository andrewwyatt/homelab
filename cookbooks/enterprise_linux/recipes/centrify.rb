###
### Cookbook Name:: enterprise_linux
### Recipe:: centrify
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
### Disable the service if the authentication mechanism is switched.
###

service 'centrifydc' do
  action [:disable, :stop]
  not_if { node['linux']['authentication']['mechanism'] == 'centrify' }
end

unless node['linux']['authentication']['mechanism'] == 'centrify'
  return
end

yum_package [ 'CentrifyDC',
              'bind-utils' ] do
  action :install
end

bash "Licensing Centrify (#{node['linux']['centrify']['license_type']})" do
  code <<-EOF
    adlicense --#{node['linux']['centrify']['license_type']}
  EOF
  sensitive node['linux']['runtime']['sensitivity']
  only_if { `adlicense -q 2>&1 | awk '{print $3}'` =~ /#{node['linux']['centrify']['license_type']}/i }
end

centrify = data_bag_item('credentials', 'centrify', IO.read(Chef::Config['encrypted_data_bag_secret']))
join_password = centrify[node['linux']['centrify']['join_user']]

notification="I'm not a member of Active Directory domain #{node['linux']['centrify']['domain']}, adding myself."
bash "Joining Domain (#{node['linux']['centrify']['domain']})" do
  code <<-EOF
    notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
    adjoin -i -y -n #{node['fqdn']} --force #{node['linux']['centrify']['client_type']} #{node['linux']['centrify']['domain']} --user #{node['linux']['centrify']['join_user']} --password '#{join_password}' ||:
  EOF
  sensitive node['linux']['runtime']['sensitivity']
  only_if { `adinfo | head -n 1` =~ /#{node['hostname']}/i }
end

notification="My DNS record does not exist in the #{node['linux']['centrify']['domain']} domain, adding myself."
bash "Ensuring DNS record for server #{node['fqdn']}" do
  code <<-EOF
    notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
    addns -U --user #{node['linux']['centrify']['join_user']} --password '#{join_password}'
  EOF
  sensitive node['linux']['runtime']['sensitivity']
  only_if { `host #{node['fqdn']} 2>&1 | grep "not found"` =~ /not found/i }
end


notification="My DNS record does not match my IP in #{node['linux']['centrify']['domain']} domain, updating."
bash "Ensuring DNS record for server #{node['fqdn']}" do
  code <<-EOF
    notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
    addns -U --user #{node['linux']['centrify']['join_user']} --password '#{join_password}'
  EOF
  sensitive node['linux']['runtime']['sensitivity']
  only_if { `ip addr | grep $(host #{node['fqdn']} 2>&1 | awk '{printf $4}') && true` == true }
end

allowed_groups = String.new
allowed_groups = node['linux']['authgroup'].join(' ')

template "/etc/centrifydc/centrifydc.conf" do
  source "etc/centrifydc/centrifydc.conf.erb"
  owner "root"
  group "root"
  mode 0600
  notifies :restart, "service[centrifydc]", :delayed
  sensitive node['linux']['runtime']['sensitivity']
  variables({
    :allowed_groups  => allowed_groups
  })
end

service "centrifydc" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end
