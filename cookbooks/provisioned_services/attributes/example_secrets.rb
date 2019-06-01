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

###
### To install, configure, and use Chef, you must accept the
### licenses.  This is set to false by default forcing the action to be taken by
### the user.
###

###
### The Chef client license can be found at the following URL:
###
### https://www.chef.io/end-user-license-agreement/
###

# default['chef']['accept_license']                 = true

# default['chef']['accept_manage_license']          = false
# default['chef']['install_manage']                 = false

# default['chef']['accept_reporting_license']       = false
# default['chef']['install_reporting']              = false

###
### Let's define hosts in this environment - usable in other locations as well.
###
### Servers are cattle, not pets.
###
### CDC0000
### ||||
### |||`> Sequence         .. 1-9999
### ||`-> Operating System .. (C)entOS, (R)edHat, (O)racle, (U)buntu, (W)indows
### |`--> Environment      .. (D)evelopment, (S)tage, (P)roduction
### `---> Topology         .. (D)MZ, (C)ore, (P)CI
###
###
### Use CNAMES for functions if desired (cobbler, packages, provisioner, chef, etc).
###

# node.normal['provisioner']['hostname_prefix']        = '{Your Hostname Prefix Here}'

# node.normal['linux']['domain_root']                  = '{Your Root Domain Here}'
# node.normal['linux']['domain_name']                  = "{Your Domain Prefix Here}.#{node['linux']['domain_root']}"
# node.normal['provisioner']['domain']                 = node['linux']['domain_name']

# node.normal['chef']['ssl']['hostnames']              = { 'hostname' => node['fqdn'],
#                                                      'cname'    => "chef.#{node['linux']['domain_name']}" }

# node.normal['provisioner']['ssl']['hostnames']       = { 'hostname' => node['fqdn'],
#                                                          'cname1'    => "mirror.#{node['linux']['domain_name']}",
#                                                          'cname2'    => "build7.#{node['linux']['domain_name']}",
#                                                          'cname3'    => "deploy.#{node['linux']['domain_name']}"}

# node.normal['linux']['slack_enabled']                = true
# node.normal['linux']['slack_channel']                = '{Your Slack Channel Here}'
# node.normal['linux']['api_path']                     = '{Your API Key Here}'

# node.normal['chef']['slack_enabled']                 = true
# node.normal['chef']['slack_channel']                 = '{Your Slack Channel Here}'
# node.normal['chef']['api_path']                      = '{Your API Key Here}'

# node.normal['provisioner']['slack_enabled']          = true
# node.normal['provisioner']['slack_channel']          = '{Your Slack Channel Here}'
# node.normal['provisioner']['api_path']               = '{Your API Key Here}'

# node.normal['provisioner']['hostname_auth_token']    = '{Your Name Generator Auth Token Here}'

# node.normal['linux']['jumpcloud']['server_groupid']  = '{Your JumpCloud Server GID Here}'

# node.normal['linux']['runtime']['sensitivity']       = true
# node.normal['chef']['runtime']['sensitivity']        = true
# node.normal['provisioner']['runtime']['sensitivity'] = true

# node.normal['chef']['install_from_source']           = false

# node.normal['chef']['default_organization']          = '{Your Chef Org Short Name Here}'
# node.normal['linux']['org_abbreviation']             = node['chef']['default_organization']

# node.normal['chef']['organizations']['home']['short_name']                           = node['chef']['default_organization']
# node.normal['chef']['organizations']['home']['full_name']                            = node['linux']['domain_name']
# node.normal['chef']['organizations']['home']['validator']                            = "#{node['chef']['default_organization']}-validator"
# node.normal['chef']['organizations']['home']['environment']                          = node['chef']['default_organization']
# node.normal['chef']['organizations']['home']['run_list']                             = 'provisioned_services::standard_server'
# node.normal['chef']['organizations']['home']['admin_user']['username']               = 'admin'
# node.normal['chef']['organizations']['home']['admin_user']['first_name']             = 'Systems'
# node.normal['chef']['organizations']['home']['admin_user']['last_name']              = 'Administrator'
# node.normal['chef']['organizations']['home']['admin_user']['email']                  = "admin@#{node['linux']['domain_name']}"
# node.normal['chef']['organizations']['home']['groups']['admin']                      = '{JumpCloud Admin GID Here}'
# node.normal['chef']['organizations']['home']['groups']['users']                      = '{JumpCloud User GID Here}'
# node.normal['chef']['organizations']['home']['unmanaged_accounts']                   = [ 'admin', 'pivotal', 'delivery' ]

# node.normal['chef']['server_attributes']['ldap']['base_dn']             = '{BASEDN Here}'
# node.normal['chef']['server_attributes']['ldap']['bind_dn']             = '{BINDDN Here}'
# node.normal['chef']['server_attributes']['ldap']['host']                = 'ldap.jumpcloud.com'
# node.normal['chef']['server_attributes']['ldap']['enable_tls']          = 'true'
# node.normal['chef']['server_attributes']['ldap']['port']                = '389'
# node.normal['chef']['server_attributes']['ldap']['login_attribute']     = 'uid'

# node.normal['chef']['server_attributes']['nginx']['ssl_certificate']     = "/etc/opscode/#{node['fqdn']}.crt"
# node.normal['chef']['server_attributes']['nginx']['ssl_certificate_key'] = "/etc/opscode/#{node['fqdn']}.pem"
# node.normal['chef']['server_attributes']['nginx']['ssl_protocols']       = 'TLSv1.1 TLSv1.2'

###
### Follow the JumpCloud procedures for enabling a Samba authentication user.  Set the service password in:
###
### Credentials -> passwords -> samba_passwd
###

# node.normal['samba']['server_attributes']['ldap']['base_dn'] = '{Your JumpCloud BaseDN}'
# node.normal['samba']['server_attributes']['ldap']['bind_dn'] = '{Your JumpCloud Samba Service Account}'
# node.normal['samba']['server_attributes']['ldap']['host']    = 'ldapsam:ldaps://ldap.jumpcloud.com:636'
# node.normal['samba']['server_attributes']['ldap']['users']   = 'ou=Users'
# node.normal['samba']['server_attributes']['ldap']['group']   = 'ou=Users'
# node.normal['samba']['server_attributes']['ldap']['users']   = 'Users'

###
### OpenVPN configuration, set the service account password in:
###
### ### Credentials -> passwords -> openvpn_passwd
###

# node.normal['openvpn']['port']                                    = '1194'
# node.normal['openvpn']['protocol']                                = 'udp'
# node.normal['openvpn']['max_clients']                             = '100'
# node.normal['openvpn']['routes']['0']                             = '10.100.100.0 255.255.255.0'
# node.normal['openvpn']['easyrsa_url']                             = 'https://github.com/OpenVPN/easy-rsa/releases/download'
# node.normal['openvpn']['easyrsa_version']                         = 'v3.0.6'
# node.normal['openvpn']['easyrsa_package']                         = 'EasyRSA-unix-v3.0.6.tgz'

# node.normal['openvpn']['ldap']['host']                            = 'ldaps://ldap.jumpcloud.com:636'
# node.normal['openvpn']['ldap']['base_dn']                         = ''
# node.normal['openvpn']['ldap']['bind_dn']                         = ''
