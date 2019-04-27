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

# default['provisioner']['hostname_prefix']        = '{Your Hostname Prefix Here}'

# default['linux']['domain_root']                  = '{Your Root Domain Here}'
# default['linux']['domain_name']                  = "{Your Domain Prefix Here}.#{node['linux']['domain_root']}"
# default['provisioner']['domain']                 = node['linux']['domain_name']

# default['chef']['ssl']['hostnames']              = { 'hostname' => node['fqdn'],
#                                                      'cname'    => "chef.#{node['linux']['domain_name']}" }

# default['linux']['slack_enabled']                = true
# default['linux']['slack_channel']                = '{Your Slack Channel Here}'
# default['linux']['api_path']                     = '{Your API Key Here}'

# default['chef']['slack_enabled']                 = true
# default['chef']['slack_channel']                 = '{Your Slack Channel Here}'
# default['chef']['api_path']                      = '{Your API Key Here}'

# default['provisioner']['slack_enabled']          = true
# default['provisioner']['slack_channel']          = '{Your Slack Channel Here}'
# default['provisioner']['api_path']               = '{Your API Key Here}'

# default['provisioner']['hostname_auth_token']    = '{Your Name Generator Auth Token Here}'

# default['linux']['jumpcloud']['server_groupid']  = '{Your JumpCloud Server GID Here}'

# default['linux']['runtime']['sensitivity']       = true
# default['chef']['runtime']['sensitivity']        = true
# default['provisioner']['runtime']['sensitivity'] = true

# default['chef']['install_from_source']           = false

# default['chef']['default_organization']          = '{Your Chef Org Short Name Here}'
# default['linux']['org_abbreviation']             = node['chef']['default_organization']

# default['chef']['organizations']['home']['short_name']                           = node['chef']['default_organization']
# default['chef']['organizations']['home']['full_name']                            = node['linux']['domain_name']
# default['chef']['organizations']['home']['validator']                            = "#{node['chef']['default_organization']}-validator"
# default['chef']['organizations']['home']['environment']                          = node['chef']['default_organization']
# default['chef']['organizations']['home']['run_list']                             = 'provisioned_services::standard_server'
# default['chef']['organizations']['home']['admin_user']['username']               = 'admin'
# default['chef']['organizations']['home']['admin_user']['first_name']             = 'Systems'
# default['chef']['organizations']['home']['admin_user']['last_name']              = 'Administrator'
# default['chef']['organizations']['home']['admin_user']['email']                  = "admin@#{node['linux']['domain_name']}"
# default['chef']['organizations']['home']['groups']['admin']                      = '{JumpCloud Admin GID Here}'
# default['chef']['organizations']['home']['groups']['users']                      = '{JumpCloud User GID Here}'
# default['chef']['organizations']['home']['unmanaged_accounts']                   = [ 'admin', 'pivotal', 'delivery' ]

# default['chef']['server_attributes']['ldap']['base_dn']             = '{BASEDN Here}'
# default['chef']['server_attributes']['ldap']['bind_dn']             = '{BINDDN Here}'
# default['chef']['server_attributes']['ldap']['host']                = 'ldap.jumpcloud.com'
# default['chef']['server_attributes']['ldap']['enable_tls']          = 'true'
# default['chef']['server_attributes']['ldap']['port']                = '389'
# default['chef']['server_attributes']['ldap']['login_attribute']     = 'uid'

# default['chef']['server_attributes']['nginx']['ssl_certificate']     = "/etc/opscode/#{node['fqdn']}.crt"
# default['chef']['server_attributes']['nginx']['ssl_certificate_key'] = "/etc/opscode/#{node['fqdn']}.pem"
# default['chef']['server_attributes']['nginx']['ssl_protocols']       = 'TLSv1.1 TLSv1.2'

###
### Follow the JumpCloud procedures for enabling a Samba authentication user.  Set the service password in:
###
### Credentials -> passwords -> samba_passwd
###

# default['samba']['server_attributes']['ldap']['base_dn'] = '{Your JumpCloud BaseDN}'
# default['samba']['server_attributes']['ldap']['bind_dn'] = '{Your JumpCloud Samba Service Account}'
# default['samba']['server_attributes']['ldap']['host']    = 'ldapsam:ldaps://ldap.jumpcloud.com:636'
# default['samba']['server_attributes']['ldap']['users']   = 'ou=Users'
# default['samba']['server_attributes']['ldap']['group']   = 'ou=Users'
# default['samba']['server_attributes']['ldap']['users']   = 'Users'
