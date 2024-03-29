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

authorized_users = {}

###
### Walk each organization and build the map of users.
###

node['chef']['organizations'].each do |org_name, organization|
  ###
  ### Map built in accounts so the recipe can ignore them.
  ###
  organization['unmanaged_accounts'].each do |account|
    authorized_users[account] = {}
    authorized_users[account][org_name] = {}
    authorized_users[account][org_name]['type'] = 'local'
    authorized_users[account][org_name]['access'] = 'admin'
  end

  ###
  ### Inspect each group and build an access table.
  ###

  organization['groups'].each do |chef_group, groupid|
    cudata = `curl -X GET https://console.jumpcloud.com/api/v2/usergroups/#{groupid}/members \
                   -H 'Accept: application/json' \
                   -H 'Content-Type: application/json' \
                   -H 'x-api-key: #{passwords['jumpcloud_api']}' 2>/dev/null`

    ###
    ### If the recipe can't access the JumpCloud, quit so users don't
    ### get clobbered.
    ###

    if $CHILD_STATUS.exitstatus > 0
      return 0
    end

    if cudata.empty?
      return 0
    end

    cuattrs = JSON.parse(cudata)

    cuattrs.each do |key|
      key.each do |_key, member|
        next unless member.is_a?(Hash)
        mdata = `curl -X GET https://console.jumpcloud.com/api/systemusers/#{member['id']} \
                        -H 'Accept: application/json' \
                        -H 'Content-Type: application/json' \
                        -H 'x-api-key: #{passwords['jumpcloud_api']}' 2>/dev/null`

        ###
        ### If the recipe can't access the JumpCloud, quit so users don't
        ### get clobbered.
        ###

        if $CHILD_STATUS.exitstatus > 0
          return 0
        end

        if mdata.empty?
          return 0
        end
        mattrs = JSON.parse(mdata)

        unless authorized_users[mattrs['username']].is_a?(Hash)
          authorized_users[mattrs['username']] = {}
        end

        unless authorized_users[mattrs['username']][org_name].is_a?(Hash)
          authorized_users[mattrs['username']][org_name] = {}
        end

        authorized_users[mattrs['username']][org_name]['firstname'] = mattrs['firstname']
        authorized_users[mattrs['username']][org_name]['lastname'] = mattrs['lastname']
        authorized_users[mattrs['username']][org_name]['email'] = mattrs['email']
        authorized_users[mattrs['username']][org_name]['type'] = 'JumpCloud'
        authorized_users[mattrs['username']][org_name]['access'] = if chef_group =~ /admin/
                                                                     'admin'
                                                                   else
                                                                     'user'
                                                                   end
      end
    end
  end
end

###
### Using the access table, process revocations by comparing users to the chef
### accounts list.
###

existing_chef_accounts.each do |account|
  execute 'Processing account revocations.' do # ~FC022
    command "chef-server-ctl user-delete #{account} -R -y ||:; \
             notify \"#{node['chef']['slack_channel']}\" \"#{node['chef']['emoji']}\" \"#{node['chef']['api_path']}\" \"User #{account} has been revoked from the Chef server.\""
    action :run
    sensitive node['chef']['runtime']['sensitivity']
    not_if { authorized_users[account].is_a?(Hash) == true }
  end
end

###
### Once users are revoked from Chef, process the users granted access.
###

authorized_users.each do |account, map|
  map.each do |org, attributes|
    ###
    ### Local accounts (defined in the org attributes) get ignored.
    ###
    if attributes['type'] == 'local'
      break
    end
    existing_account = existing_chef_accounts.each do |existing_account|
      if account == existing_account
        break true
      end
    end
    password = ''
    passchars = '!#%^:,./?1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    length = (16 + rand(8))
    (0..length).each do
      paschar = passchars[(rand(passchars.length) - 1)]
      password << paschar
    end
    execute 'Processing account additions (account).' do # ~FC022
      command "chef-server-ctl user-create #{account} #{attributes['firstname']} #{attributes['lastname']} #{attributes['email']} \'#{password}\'; \
               notify \"#{node['chef']['slack_channel']}\" \"#{node['chef']['emoji']}\" \"#{node['chef']['api_path']}\" \"User #{account} has been granted access to the Chef server.\""
      action :run
      sensitive node['chef']['runtime']['sensitivity']
      not_if { existing_account == true }
    end
    execute 'Processing account notifications.' do # ~FC022
      command <<-EOC
cat << EOF | mail -t
From: Account Management <chef_accounts@#{node['fqdn']}>
To: #{attributes['firstname']} #{attributes['lastname']} <#{attributes['email']}>
Subject: Chef server access (#{node['fqdn']}) (DO NOT REPLY)
Content-Type: text/html
MIME-Version: 1.0

Hello #{attributes['firstname']} #{attributes['lastname']}!  You have been provisioned access to the #{node['chef']['runtime']['environment']} Chef server https://#{node['fqdn']}.  You have been generated a temporary password of '#{password}'.  Please log in and link your Chef account to your Active Directory account as soon as possible.  The system generated password will expire on first use.  Once logged into Chef, browse to Administration > Users, and reset your private key.  Save the private key to #{account}.pem when configuring knife for access to the Chef server.

You can configure knife by cloning the knifectl project (https://github.com/andrewwyatt/knifecfg) on Github.

Thank you,
Chef Account Management

EOF
      EOC
      action :run
      sensitive node['chef']['runtime']['sensitivity']
      not_if { existing_account == true }
      only_if { node['chef']['install_manage'] == true }
    end

    ###
    ### Ensure the user is a member of the appropriate orgs.
    ###
    next if attributes['type'] == 'local'
    json = `chef-server-ctl user-show #{account} -l -F json 2>/dev/null ||:`
    if json.empty?
      return 0
    end
    account_attributes = JSON.parse(json)
    add_to_org = false

    unless account_attributes['organizations'].is_a?(Array) && account_attributes['organizations'].include?(org)
      add_to_org = true
    end

    if attributes['access'] == 'admin'
      admin = '--admin'
    end

    execute "Adding #{attributes['firstname']} #{attributes['lastname']} to the #{org} org." do
      command "chef-server-ctl org-user-add #{org} #{account} #{admin}; \
               notify \"#{node['chef']['slack_channel']}\" \"#{node['chef']['emoji']}\" \"#{node['chef']['api_path']}\" \"User #{account} has been granted #{attributes['access']} access to the #{org} organization.\""
      action :run
      sensitive node['chef']['runtime']['sensitivity']
      only_if { add_to_org == true }
    end
  end
end
