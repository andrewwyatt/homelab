###
### Cookbook Name:: lab_management
### Recipe:: lab_build
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
### This is the initial lab build recipe, use it first before applying other
### recipes to the system.  Once run, remove it.
###

###
### It does not contain chef client management, or the AD integration recipes.
###

include_recipe 'enterprise_linux::hosts'
include_recipe 'enterprise_linux::mounts'
include_recipe 'enterprise_linux::resolv'
include_recipe 'enterprise_linux::selinux'
include_recipe 'enterprise_linux::slack'
include_recipe 'enterprise_linux::init'
include_recipe 'enterprise_linux::login'
include_recipe 'enterprise_linux::pam'
include_recipe 'enterprise_linux::local_users'
include_recipe 'enterprise_linux::banner'
include_recipe 'enterprise_linux::timezone'
include_recipe 'enterprise_linux::ntp'
include_recipe 'enterprise_linux::yum'
include_recipe 'enterprise_linux::common'
include_recipe 'enterprise_linux::vmware'
include_recipe 'enterprise_linux::security'
include_recipe 'enterprise_linux::shells'
include_recipe 'enterprise_linux::sudoers'
include_recipe 'enterprise_linux::cron'
include_recipe 'enterprise_linux::sysctl'
include_recipe 'enterprise_linux::limits'
include_recipe 'enterprise_linux::logrotate'
include_recipe 'enterprise_linux::rsyslog'
include_recipe 'enterprise_linux::postfix'
include_recipe 'enterprise_linux::openssh'
#include_recipe 'enterprise_linux::cobbler'
include_recipe 'enterprise_linux::autoupdate'
