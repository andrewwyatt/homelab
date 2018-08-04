###
### Cookbook Name:: enterprise_linux
### Recipe:: pam
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

### This makes me feel dirty, but pam sucks.

bash "Ensure PAM password retries= and minlen=" do
  code <<-EOF
     sed -i "s/pam_cracklib.so try_first_pass.*\$/pam_cracklib.so try_first_pass #{node['linux']['auth']['cracklib']}/" /etc/pam.d/system-auth
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end

bash "Ensure PAM password sufficent" do
  code <<-EOF
     sed -i "s/password    sufficient    pam_unix.so.*\$/password    sufficient    pam_unix.so #{node['linux']['auth']['password_sufficient']}/" /etc/pam.d/system-auth
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end

bash "Ensure only members of the wheel group can su" do
  code <<-EOF
    sed -i "s/^#auth[[:blank:]]\+required[[:blank:]]\+pam_wheel.so[[:blank:]]\+use_uid/auth\t\trequired\tpam_wheel.so use_uid/" /etc/pam.d/su
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end

template '/etc/security/pwquality.conf' do
  source "etc/security/pwquality.conf.erb"
  owner 'root'
  group 'root'
  mode '0644'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end
