###
### Cookbook:: chef
### Default Attributes
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
### *** NOTICE *** NOTICE *** NOTICE *** NOTICE *** NOTICE *** NOTICE ***
###
### READ THIS ATTRIBUTES DEFINITION IN ITS ENTIRETY.  IT MUST BE CONFIGURED
### FOR YOUR ENVIRONMENT, OR IT WILL FAIL TO WORK PROPERLY.
###
### *** NOTICE *** NOTICE *** NOTICE *** NOTICE *** NOTICE *** NOTICE ***
###

###
### To install and configure Chef manage and reporting, you must accept the
### license.  This is set to false by default forcing the action to be taken by
### the user.
###

default['chef']['accept_manage_license']          = false
default['chef']['install_manage']                 = false

default['chef']['accept_reporting_license']       = false
default['chef']['install_reporting']              = false

###
### Chef software versions to be deployed or upgraded by this cookbook.
###

default['chef']['client_version']                = '14.3.37'
default['chef']['server_version']                = '12.17.33'
default['chef']['manage_version']                = '2.5.16'
default['chef']['reporting_version']             = '1.8.0'


###
### I want some notifications to go to Slack, so we'll define the attributes here.
###

default['chef']['slack_enabled']                 = false
default['chef']['slack_channel']                 = '#homelab'
default['chef']['api_path']                      = 'APIKEYGOESHERE'
default['chef']['slack_name']                    = 'Chef_Management'
default['chef']['slack_emoji']                   = ':chef:'
default['chef']['bootstrap_name']                = 'Bootstrap'
default['chef']['bootstrap_emoji']               = ':sunglasses:'

###
### Define sensitivity as an attribute so we can override it when necessary
### for troubleshooting.
###

default['chef']['runtime']['sensitivity']        = true

###
### Set up the file header to follow the enterprise linux cookbook header.
###

default['chef']['file_header']                   = node['linux']['chef']['file_header']

###
### Define the tags for Chef masters and workers.  This is useful for pipeline
### integration, ex:
###
### knife search 'tags:chef-server AND tags:master' -i 2>/dev/null
###

default['chef']['master_tag']                    = "master"
default['chef']['worker_tag']                    = "worker"

###
### Configure various metadata about Chef software, and where to find it.
###

default['chef']['install_branch']                = 'stable'
default['chef']['install_from_source']           = true

default['chef']['client_url']                    = "https://packages.chef.io/files/#{node['chef']['install_branch']}/chef/#{node['chef']['client_version']}/el/"
default['chef']['server_url']                    = "https://packages.chef.io/files/#{node['chef']['install_branch']}/chef-server/#{node['chef']['server_version']}/el/"
default['chef']['manage_url']                    = "https://packages.chef.io/files/#{node['chef']['install_branch']}/chef-manage/#{node['chef']['manage_version']}/el/"
default['chef']['reporting_url']                 = "https://packages.chef.io/files/#{node['chef']['install_branch']}/opscode-reporting/#{node['chef']['reporting_version']}/el/"

default['chef']['bootstrap_delay']               = 30
default['chef']['bootstrap_user']                = 'admin'
default['chef']['bootstrap_root']                = '/node/'

default['chef']['cert_domain']                   = 'lab.fewt.com'
default['chef']['ad_bind_account']               = 'chef_authenticator'

### Chef server bits
default['chef']['default_organization']          = 'lab'
default['chef']['organizations']                 = { 'lab'        => { 'short_name'          => 'lab',
                                                                       'full_name'           => 'lab.fewt.com',
                                                                       'validator'           => 'lab-validator',
                                                                       'environment'         => 'lab',
                                                                       'run_list'            => 'lab_management::standard_server',
                                                                       'admin_user'          => { 'username'   => 'admin',
                                                                                                  'first_name' => 'Systems',
                                                                                                  'last_name'  => 'Administrator',
                                                                                                  'email'      => 'admin@lab.fewt.com'
                                                                                                },
                                                                       'groups'              => { 'admin'        => '{JUMPCLOUD ADMIN GROUP ID}',
                                                                                                  'users'        => '{JUMPCLOUD USER GROUP ID}'
                                                                                                },
                                                                       'unmanaged_accounts'  => [ 'admin',
                                                                                                  'pivotal',
                                                                                                  'delivery'
                                                                                                ]
                                                                     }
                                                   }

###
### This is the directory where the admin and validation keys will be stored on the Chef server.
###

default['chef']['keys']                           = "/etc/opscode/keys"

###
### This will configure the cookbook to mirror whichever Chef server the node is
### connected too.  If we only want to mirror it once, set sync to false.
###

default['chef']['sync']                           = true
default['chef']['mirror_root']                    = '/var/opt/chef/mirror'
default['chef']['mirror']                         = [ 'data_bags',
                                                      'environments',
                                                      'cookbooks' ]

###
### Setting the sync_host attribute to a host will force the cookbook to always replicate
### from the target Chef server.  If left blank, the cookbook will use its master Chef
### instance as the replication source.
###

default['chef']['sync_host']                      = ''

###
### Manage the Chef Server configuration, this is defaulted to true.  When
### enabled, any changes to the Chef server attributes will cause a reconfigure.
###

default['chef']['manage_chef']                = true

###
### This hash should be used to define additional attributes that don't fall into any other catagories above.  This would
### include attributes added to Chef to correct bugs, or provide service optimizations.
###

default['chef']['server_attributes']             = { }

### Disabled, Automate license has expired.
# 'data_collector' => { 'root_url' => 'https://automate.lab.fewt.com/data-collector/v0/' },
# 'profiles'       => { 'root_url' => "https://automate.lab.fewt.com" }

###
### Manage the Chef Manage configuration file.  This is default true. When
### enabled, any changes to the Chef Manage attributes will cause a reconfigure.
###

default['chef']['manage_manage']         = true
default['chef']['manage_attributes']             = { 'org_creation_enabled' => 'org_creation_enabled false',
                                                     'disable_sign_up'      => 'disable_sign_up true'
                                                   }
