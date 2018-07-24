###
### Cookbook:: lab_management
### Recipe:: rebuild_server
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

node.default['linux']['decom']['final_task']   = 'shutdown -r now'
node.default['linux']['decom']['decom_notice'] = 'You want me to rebuild myself?  Really?  Oh, alright!'

include_recipe 'enterprise_linux::decom'
