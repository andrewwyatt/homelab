###
### Cookbook Name:: enterprise_linux
### Recipe:: vmware
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

yum_package [ 'dmidecode' ] do
  action :install
end

if ::File.exist?('/usr/sbin/dmidecode')
  product_name = `/usr/sbin/dmidecode -s system-product-name`
end

yum_package [ 'open-vm-tools' ] do
  action :install
  only_if { product_name =~ /VMware/i }
end

service 'vmtoolsd' do
  supports status: true, restart: true
  action [ :enable, :start ]
  only_if { product_name =~ /VMware/i }
end
