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

yum_package [ 'CentrifyDC',
              'bind-utils' ] do
  action :install
end

license=`adlicense -q 2>&1 | awk '{print $3}'`
unless license =~ /#{node['linux']['centrify']['license_type']}/i
  bash "Licensing Centrify (#{node['linux']['centrify']['license_type']})" do
    code <<-EOF
      adlicense --#{node['linux']['centrify']['license_type']}
    EOF
    sensitive node['linux']['runtime']['sensitivity']
  end
end

centrify = data_bag_item('credentials', 'centrify', IO.read(Chef::Config['encrypted_data_bag_secret']))
join_password = centrify[node['linux']['centrify']['join_user']]

joined_test=`adinfo | head -n 1`
unless joined_test =~/#{node['hostname']}/i
  notification="I'm not a member of Active Directory domain #{node['linux']['centrify']['domain']}, adding myself."
  bash "Joining Domain (#{node['linux']['centrify']['domain']})" do
    code <<-EOF
      notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
      adjoin -i -y -n #{node['fqdn']} --force #{node['linux']['centrify']['client_type']} #{node['linux']['centrify']['domain']} --user #{node['linux']['centrify']['join_user']} --password '#{join_password}' ||:
    EOF
    sensitive node['linux']['runtime']['sensitivity']
  end
end

dns_test=`host #{node['fqdn']} 2>&1 | grep "not found"`
if dns_test =~/not found/i
  notification="My DNS record does not exist in the #{node['linux']['centrify']['domain']} domain, adding myself."
  bash "Ensuring DNS record for server #{node['fqdn']}" do
    code <<-EOF
      notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
      addns -U --user #{node['linux']['centrify']['join_user']} --password '#{join_password}'
    EOF
    sensitive node['linux']['runtime']['sensitivity']
  end
end

dns_test=`ip addr | grep $(host #{node['fqdn']} 2>&1 | awk '{printf $4}')`
unless $?.exitstatus == 0
  notification="My DNS record does not match my IP in #{node['linux']['centrify']['domain']} domain, updating."
  bash "Ensuring DNS record for server #{node['fqdn']}" do
    code <<-EOF
      notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
      addns -U --user #{node['linux']['centrify']['join_user']} --password '#{join_password}'
    EOF
    sensitive node['linux']['runtime']['sensitivity']
  end
end

template "/etc/centrifydc/centrifydc.conf" do
  source "etc/centrifydc/centrifydc.conf.erb"
  owner "root"
  group "root"
  mode 0600
  notifies :restart, "service[centrifydc]", :delayed
  sensitive node['linux']['runtime']['sensitivity']
end

service "centrifydc" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end
