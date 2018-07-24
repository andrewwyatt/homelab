###
### Cookbook Name:: enterprise_linux
### Recipe:: yum
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

Dir["/etc/yum.repos.d/*CentOS*"].each do |path|
  file ::File.expand_path(path) do
    action :delete
  end
end

Dir["/etc/yum.repos.d/*epel*"].each do |path|
  file ::File.expand_path(path) do
    action :delete
  end
end

###
### This is to support mirrors from upstream
###

template "/etc/yum.repos.d/upstream.repo" do
  owner 'root'
  group 'root'
  mode   0644
  source 'etc/yum.repos.d/mirrored.repo.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
  variables({
    :mirror      => "CentOS_#{node['platform_version'][0]}_x86_64",
  })
end

###
### This is to support local repositories for packages managed internally
###

template "/etc/yum.repos.d/local.repo" do
  owner 'root'
  group 'root'
  mode   0644
  source 'etc/yum.repos.d/local.repo.erb'
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end
