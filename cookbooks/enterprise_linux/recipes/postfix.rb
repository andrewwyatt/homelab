###
### Cookbook Name:: enterprise_linux
### Recipe:: postfix
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
### Encrypted passwords are stored in the credentials > passwords encrypted
### data bag.
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

yum_package [ 'postfix',
              'cyrus-sasl-plain',
               'mailx' ] do
  action :install
end

template "/etc/postfix/main.cf" do
  source "etc/postfix/main.cf.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  notifies :restart, "service[postfix]", :immediately
end

 file "/etc/postfix/sasl_passwd" do
   owner "root"
   group "root"
   mode 0600
   content passwords['sasl_passwd']
   action :create
   only_if { node['linux']['postfix']['smtp_sasl_auth_enable'] == "yes" }
   only_if { (defined?(passwords['sasl_passwd'])).nil? == false }
 end

 execute "Configuring postfix SASL creds." do
   command "postmap /etc/postfix/sasl_passwd"
   action :run
   notifies :restart, "service[postfix]", :immediately
   not_if { ::File.exists?("/etc/postfix/sasl_passwd.db") }
   only_if { node['linux']['postfix']['smtp_sasl_auth_enable'] == "yes" }
   only_if { (defined?(passwords['sasl_passwd'])).nil? == false }
 end

service "postfix" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end
