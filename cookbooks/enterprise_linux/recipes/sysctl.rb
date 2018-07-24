###
### Cookbook Name:: enterprise_linux
### Recipe:: sysctl
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

template '/etc/sysctl.conf' do
  owner 'root'
  group 'root'
  mode   0644
  source 'etc/sysctl.conf.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

bash "Refreshing sysctl if necessary" do
  code <<-EOF
    if [ -e "/etc/.sysctl.hash" ]
    then
      PREVSUM=$(cat /etc/.sysctl.hash)
    fi
    SUM=$(sha256sum /etc/sysctl.conf | awk '{print $1}')
    if [ ! "${SUM}" = "${PREVSUM}" ]
    then
      /sbin/sysctl -p
      echo "${SUM}" >/etc/.sysctl.hash
    fi
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end
