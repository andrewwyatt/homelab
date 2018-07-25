###
### Cookbook:: chef
### Recipe:: configure_users
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
### Flush the AD cache so we're always getting fresh data from AD, otherwise
### we may get stale data from Centrify.
###

adflush=`adflush >/dev/null 2>&1`

###
### Build an array of accounts that are currently provisioned on the Chef
### server.
###

existing_chef_accounts = Array.new(`chef-server-ctl user-list | grep ^[a-Z]`.split("\n"))

###
### Create a hash of users that are authorized to use the server.
###
### Schema: authorized_users['username'] => org => { 'type'   => '[ad,local]',
###                                                  'access' => '[admin,user]' }
###

authorized_users=Hash.new

###
### Walk each organization and build the map of users.
###

node['chef']['organizations'].each do | org_name , organization |

  ###
  ### Map built in accounts so the recipe can ignore them.
  ###
  organization['unmanaged_accounts'].each do | account |
    authorized_users[account] = Hash.new
    authorized_users[account][org_name] = Hash.new
    authorized_users[account][org_name]['type'] = 'local'
    authorized_users[account][org_name]['access'] = 'admin'
  end

  ###
  ### Inspect each AD group and build an access table.
  ###

  organization['groups'].each do | chef_group, group |
    chef_members=`adquery group #{group} -m`.split("\n")
    chef_members.each do | account |
      authorized_users[account] = Hash.new
      authorized_users[account][org_name] = Hash.new
      authorized_users[account][org_name]['type'] = 'ad'
      if chef_group =~ /admin/
        authorized_users[account][org_name]['access'] = 'admin'
      else
        authorized_users[account][org_name]['access'] = 'user'
      end
    end
  end
end

###
### Using the access table, process revocations by comparing users to the chef
### accounts list.
###

existing_chef_accounts.each do | account |
  execute "Processing account revocations." do #~FC022
    command "chef-server-ctl user-delete #{account} -R -y ||:; \
             notify \"#{node['fqdn']}\" \"#{node['chef']['slack_channel']}\" \"#{node['chef']['emoji']}\" \"#{node['chef']['api_path']}\" \"#{account} has been revoked from the Chef server.\""
    action :run
    sensitive node['chef']['runtime']['sensitivity']
    not_if { authorized_users[account].is_a?(Hash) == true }
  end
end

###
### Once users are revoked from Chef, process the users granted access.
###

authorized_users.each do | account, map |
  map.each do | org, attributes |
    ###
    ### Local accounts (defined in the org attributes) get ignored.
    ###
    if attributes['type'] == "local"
      break
    end
    existing_account = existing_chef_accounts.each do | existing_account |
      if account == existing_account
        break true
      end
    end
    password = ""
    passchars='!#%^:,./?1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    length=(16+rand(8))
    (0..length).each do
       paschar=passchars[(rand(passchars.length)-1)]
       password << paschar
    end
    ufirst=`adquery user -p #{account} | awk '{printf $1}'`
    ulast=`adquery user -p #{account} | awk '{printf $2}'`
    email=`printf $(adquery user -b mail #{account})`
    execute "Processing account additions (account)." do #~FC022
      command "chef-server-ctl user-create #{account} #{ufirst} #{ulast} #{email} \'#{password}\'; \
               notify \"#{node['fqdn']}\" \"#{node['chef']['slack_channel']}\" \"#{node['chef']['emoji']}\" \"#{node['chef']['api_path']}\" \"#{account} has been granted access to Chef.\""
      action :run
      sensitive node['chef']['runtime']['sensitivity']
      not_if { existing_account == true }
    end
    execute "Processing account notifications." do #~FC022
      command <<-EOC
cat << EOF | mail -t
From: Account Management <chef_accounts@#{node['fqdn']}>
To: #{ufirst} #{ulast} <#{email}>
Subject: Chef server access (#{node['fqdn']}) (DO NOT REPLY)
Content-Type: text/html
MIME-Version: 1.0

Hello #{ufirst} #{ulast}!  You have been provisioned access to the #{node['chef']['runtime']['environment']} Chef server <a href="https://#{node['fqdn']}">https://#{node['fqdn']}</a>, servicing the #{node['chef']['runtime']['network']} network.  You have been generated a temporary password of '#{password}'.  Please log in and link your Chef account to your Active Directory account as soon as possible.  The system generated password will expire on first use.  Once logged into Chef, browse to Administration > Users, and reset your private key.  Save the private key to #{account}.pem when configuring knife for access to the Chef server.

You can configure knife by cloning the <a href="https://github.com/andrewwyatt/knifecfg">knifectl</a> project on Github.

Thank you,
Chef Account Management

EOF
      EOC
      action :run
      sensitive node['chef']['runtime']['sensitivity']
      not_if { existing_account == true }
    end
    ###
    ### Ensure the user is a member of the appropriate orgs.
    ###
    unless attributes['type'] == "local"
      association = String.new
      json=`chef-server-ctl user-show #{account} -l -F json 2>/dev/null ||:`
      if json.length < 1
        json = "{}"
      end
      account_attributes=JSON.parse(json)
      add_to_org = false
      if account_attributes['organizations'].is_a?(Array)
        account_attributes['organizations'].each do | value |
          unless org == value
            add_to_org = true
          else
            add_to_org = false
          end
        end
      else
        add_to_org = true
      end
      if attributes['account'] == 'admin'
        admin = '--admin'
      end
      execute "Adding #{ufirst} #{ulast} to the #{org} org." do
        command "chef-server-ctl org-user-add #{org} #{account} #{admin}; \
                 notify \"#{node['fqdn']}\" \"#{node['chef']['slack_channel']}\" \"#{node['chef']['emoji']}\" \"#{node['chef']['api_path']}\" \"#{account} has been granted #{attributes['account']} access to the #{org}\""
        action :run
        sensitive node['chef']['runtime']['sensitivity']
        only_if { add_to_org == true }
      end
    end
  end
end
