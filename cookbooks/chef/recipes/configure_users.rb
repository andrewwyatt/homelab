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
### Encrypted passwords are stored in the credentials > passwords encrypted
### data bag.
###

passwords = data_bag_item('credentials', 'passwords', IO.read(Chef::Config['encrypted_data_bag_secret']))

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
  ### Inspect each group and build an access table.
  ###

  organization['groups'].each do | chef_group, groupid |
    cudata = `curl -X GET https://console.jumpcloud.com/api/v2/usergroups/#{groupid}/members \
                   -H 'Accept: application/json' \
                   -H 'Content-Type: application/json' \
                   -H 'x-api-key: #{passwords['jumpcloud_api']}' 2>/dev/null`

    if cudata.length < 1
      cudata = "{}"
    end

    cuattrs = Hash.new
    cuattrs = JSON.parse(cudata)

    cuattrs.each do | key |
      key.each do | key, member |
        if member.is_a?(Hash)
            mdata = `curl -X GET https://console.jumpcloud.com/api/systemusers/#{member['id']} \
                          -H 'Accept: application/json' \
                          -H 'Content-Type: application/json' \
                          -H 'x-api-key: #{passwords['jumpcloud_api']}' 2>/dev/null`
            if mdata.length < 1
              mdata = "{}"
            end
            mattrs = Hash.new
            mattrs = JSON.parse(mdata)

            authorized_users[mattrs['username']] = Hash.new
            authorized_users[mattrs['username']][org_name] = Hash.new
            authorized_users[mattrs['username']][org_name]['firstname'] = mattrs['firstname']
            authorized_users[mattrs['username']][org_name]['lastname'] = mattrs['lastname']
            authorized_users[mattrs['username']][org_name]['email'] = mattrs['email']
            authorized_users[mattrs['username']][org_name]['type'] = 'JumpCloud'
            if chef_group =~ /admin/
                authorized_users[mattrs['username']][org_name]['access'] = 'admin'
              else
                authorized_users[mattrs['username']][org_name]['access'] = 'user'
            end
        end
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
    execute "Processing account additions (account)." do #~FC022
      command "chef-server-ctl user-create #{account} #{attributes['firstname']} #{attributes['lastname']} #{attributes['email']} \'#{password}\'; \
               notify \"#{node['fqdn']}\" \"#{node['chef']['slack_channel']}\" \"#{node['chef']['emoji']}\" \"#{node['chef']['api_path']}\" \"#{account} has been granted access to Chef.\""
      action :run
      sensitive node['chef']['runtime']['sensitivity']
      not_if { existing_account == true }
    end
    execute "Processing account notifications." do #~FC022
      command <<-EOC
cat << EOF | mail -t
From: Account Management <chef_accounts@#{node['fqdn']}>
To: #{attributes['firstname']} #{attributes['lastname']} <#{attributes['email']}>
Subject: Chef server access (#{node['fqdn']}) (DO NOT REPLY)
Content-Type: text/html
MIME-Version: 1.0

Hello #{attributes['firstname']} #{attributes['lastname']}!  You have been provisioned access to the #{node['chef']['runtime']['environment']} Chef server https://#{node['fqdn']}, servicing the #{node['chef']['runtime']['network']} network.  You have been generated a temporary password of '#{password}'.  Please log in and link your Chef account to your Active Directory account as soon as possible.  The system generated password will expire on first use.  Once logged into Chef, browse to Administration > Users, and reset your private key.  Save the private key to #{account}.pem when configuring knife for access to the Chef server.

You can configure knife by cloning the knifectl project (https://github.com/andrewwyatt/knifecfg) on Github.

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
      puts attributes.to_s
      if attributes['access'] == 'admin'
        admin = '--admin'
      end
      execute "Adding #{attributes['firstname']} #{attributes['lastname']} to the #{org} org." do
        command "chef-server-ctl org-user-add #{org} #{account} #{admin}; \
                 notify \"#{node['fqdn']}\" \"#{node['chef']['slack_channel']}\" \"#{node['chef']['emoji']}\" \"#{node['chef']['api_path']}\" \"#{account} has been granted #{attributes['access']} access to the #{org}\""
        action :run
        sensitive node['chef']['runtime']['sensitivity']
        only_if { add_to_org == true }
      end
    end
  end
end
