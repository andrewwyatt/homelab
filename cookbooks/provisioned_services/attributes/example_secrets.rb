###
### Cookbook:: provisioned_services
### Attributes:: secrets
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
### This is the example secrets file.  Update to meet your needs, and rename to secrets.rb
###

# node.default['provisioner']['hostname_prefix']        = '{Your Hostname Prefix Here}'

# node.default['linux']['domain_root']                  = '{Your Root Domain Here}'
# node.default['linux']['domain_name']                  = "{Your Domain Prefix Here}.#{node['linux']['domain_root']}"
# node.default['provisioner']['domain']                 = node['linux']['domain_name']

# node.default['linux']['slack_enabled']                = true
# node.default['linux']['slack_channel']                = '{Your Slack Channel Here}'
# node.default['linux']['api_path']                     = '{Your API Key Here}'

# node.default['chef']['slack_enabled']                 = true
# node.default['chef']['slack_channel']                 = '{Your Slack Channel Here}'
# node.default['chef']['api_path']                      = '{Your API Key Here}'

# node.default['provisioner']['slack_enabled']          = true
# node.default['provisioner']['slack_channel']          = '{Your Slack Channel Here}'
# node.default['provisioner']['api_path']               = '{Your API Key Here}'

# node.default['provisioner']['hostname_auth_token']    = '{Your Name Generator Auth Token Here}'

# node.default['linux']['jumpcloud']['server_groupid']  = '{Your JumpCloud Server GID Here}'

# node.default['linux']['runtime']['sensitivity']       = true
# node.default['chef']['runtime']['sensitivity']        = true
# node.default['provisioner']['runtime']['sensitivity'] = true

# node.default['chef']['install_from_source']           = false

# node.default['chef']['default_organization']          = '{Your Chef Org Short Name Here}'
# node.default['linux']['org_abbreviation']             = node['chef']['default_organization']

# node.default['chef']['organizations']['home']['short_name']                           = node['chef']['default_organization']
# node.default['chef']['organizations']['home']['full_name']                            = node['linux']['domain_name']
# node.default['chef']['organizations']['home']['validator']                            = "#{node['chef']['default_organization']}-validator"
# node.default['chef']['organizations']['home']['environment']                          = node['chef']['default_organization']
# node.default['chef']['organizations']['home']['run_list']                             = 'provisioned_services::standard_server'
# node.default['chef']['organizations']['home']['admin_user']['username']               = 'admin'
# node.default['chef']['organizations']['home']['admin_user']['first_name']             = 'Systems'
# node.default['chef']['organizations']['home']['admin_user']['last_name']              = 'Administrator'
# node.default['chef']['organizations']['home']['admin_user']['email']                  = "admin@#{node['linux']['domain_name']}"
# node.default['chef']['organizations']['home']['admin_user']['groups']['admin']        = '{JumpCloud Admin GID Here}'
# node.default['chef']['organizations']['home']['admin_user']['groups']['users']        = '{JumpCloud User GID Here}'
# node.default['chef']['organizations']['home']['unmanaged_accounts']                   = [ 'admin', 'pivotal', 'delivery' ]

# node.default['chef']['server_attributes']['ldap']['base_dn']             = '{BASEDN Here}'
# node.default['chef']['server_attributes']['ldap']['bind_dn']             = '{BINDDN Here}'
# node.default['chef']['server_attributes']['ldap']['host']                = 'ldap.jumpcloud.com'
# node.default['chef']['server_attributes']['ldap']['enable_tls']          = 'true'
# node.default['chef']['server_attributes']['ldap']['port']                = '389'
# node.default['chef']['server_attributes']['ldap']['login_attribute']     = 'uid'

# node.default['chef']['server_attributes']['nginx']['ssl_certificate']     = "/etc/opscode/#{node['fqdn']}.crt"
# node.default['chef']['server_attributes']['nginx']['ssl_certificate_key'] = "/etc/opscode/#{node['fqdn']}.pem"
# node.default['chef']['server_attributes']['nginx']['ssl_protocols']       = 'TLSv1.1 TLSv1.2'
