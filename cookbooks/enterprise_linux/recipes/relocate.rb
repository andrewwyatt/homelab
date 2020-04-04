###
### Cookbook Name:: enterprise_linux
### Recipe:: relocate
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
### passfile is used to encrypt and decrypt file based Chef secrets.
###

passfile = SecureRandom.uuid
file "#{Chef::Config[:file_cache_path]}/.#{passfile}" do
  owner 'root'
  group 'root'
  mode 0600
  content passwords['bootstrap_passphrase']
  backup false
  sensitive true
  action :nothing
end

openssl_decrypt = String.new("openssl aes-256-cbc -a -d -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")

execute 'Clean any old relocation data' do
  command "rm -rf #{Chef::Config[:file_cache_path]}/.chefdata 2>/dev/null"
  action :run
  sensitive node['linux']['runtime']['sensitivity']
end

current_chef_server = `printf $(grep chef_server_url /etc/chef/client.rb  | sed -s -e "s#^.*//##" -e "s#/.*\\\$##")`
if defined?(node['linux']['chef']['new_chef_server']).nil? == false
  unless current_chef_server == node['linux']['chef']['new_chef_server']
    directory "#{Chef::Config[:file_cache_path]}/.chefdata" do
      owner 'root'
      group 'root'
      mode 0700
      action :create
    end

    node_role = ''
    node_role = node['fqdn'].gsub('.', '_')

    mychefdata = [ "/clients/#{node['fqdn']}",
                   "/nodes/#{node['fqdn']}",
                   "/roles/#{node_role}",
                   "/acls/clients/#{node['fqdn']}",
                   "/acls/nodes/#{node['fqdn']}" ]

    mychefdata.each do |bit|
      execute "Download #{bit}" do
        command "knife download #{bit} -c /etc/chef/client.rb -k /etc/chef/client.pem -u #{node['fqdn']} --chef-repo-path #{Chef::Config[:file_cache_path]}/.chefdata --server-url https://#{current_chef_server}#{node['linux']['chef']['chef_org']}"
        action :run
        sensitive node['linux']['runtime']['sensitivity']
      end
    end

    execute 'Fetch SSL certificates' do
      command "knife ssl fetch https://#{node['linux']['chef']['new_chef_server']} -c /etc/chef/client.rb"
      action :run
      sensitive node['linux']['runtime']['sensitivity']
      not_if { File.exist? "/etc/chef/trusted_certs/#{node['linux']['chef']['new_chef_server']}.crt" }
    end

    remote_file "#{Chef::Config['file_cache_path']}/#{node['linux']['chef']['bootstrap_user']}-#{current_chef_server}.pem.enc" do
      source "https://#{current_chef_server}/#{node['linux']['chef']['bootstrap_root']}#{node['linux']['chef']['bootstrap_user']}.pem.enc"
      owner 'root'
      group 'root'
      mode 0600
      sensitive node['linux']['runtime']['sensitivity']
      action :create
    end

    execute 'Configure the admin key for the current chef server' do
      command "#{openssl_decrypt} -in #{Chef::Config['file_cache_path']}/#{node['linux']['chef']['bootstrap_user']}-#{current_chef_server}.pem.enc -out /etc/chef/#{node['linux']['chef']['bootstrap_user']}-#{current_chef_server}.pem"
      action :run
      sensitive node['linux']['runtime']['sensitivity']
      notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
    end

    remote_file "#{Chef::Config['file_cache_path']}/#{node['linux']['chef']['bootstrap_user']}.pem.enc" do
      source "https://#{node['linux']['chef']['new_chef_server']}#{node['linux']['chef']['bootstrap_root']}#{node['linux']['chef']['bootstrap_user']}.pem.enc"
      owner 'root'
      group 'root'
      mode 0600
      sensitive node['linux']['runtime']['sensitivity']
      action :create
    end

    execute 'Configure the admin key for the new chef server' do
      command "#{openssl_decrypt} -in #{Chef::Config['file_cache_path']}/#{node['linux']['chef']['bootstrap_user']}.pem.enc -out /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem"
      action :run
      sensitive node['linux']['runtime']['sensitivity']
      notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
    end

    mychefdata.each do |bit|
      if bit =~ %r{^/role}
        execute "Creating role #{bit}" do
          command "knife role from file #{Chef::Config[:file_cache_path]}/.chefdata/#{bit}.json -c /etc/chef/client.rb --server-url https://#{node['linux']['chef']['new_chef_server']}#{node['linux']['chef']['chef_org']} --user #{node['linux']['chef']['bootstrap_user']} -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem"
          action :run
          sensitive node['linux']['runtime']['sensitivity']
        end
      else
        execute "Upload #{bit}" do
          command "knife upload #{bit} -c /etc/chef/client.rb --server-url https://#{node['linux']['chef']['new_chef_server']}#{node['linux']['chef']['chef_org']} --user #{node['linux']['chef']['bootstrap_user']} -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem --chef-repo-path #{Chef::Config[:file_cache_path]}/.chefdata"
          action :run
          sensitive node['linux']['runtime']['sensitivity']
        end
      end
    end

    notification = "Deleting myself from Chef server #{current_chef_server}."
    bash notification do
      code <<-EOF
        ### Sleep until the chef client has finished before trying to remove the client.
        nohup bash -c '
          while [ true ]
          do
            ps -ef | grep "[c]hef-client"
            if [ ! $? == 0 ]
            then
              sleep 10
              break
            fi
            sleep 10;
          done
          knife client reregister $(hostname -f) -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem -u #{node['linux']['chef']['bootstrap_user']} -c /etc/chef/client.rb -f /etc/chef/client.pem
          knife role delete #{node_role} --server-url https://#{current_chef_server}#{node['linux']['chef']['chef_org']} -c /etc/chef/client.rb --user #{node['linux']['chef']['bootstrap_user']} -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}-#{current_chef_server}.pem -y
          knife node delete #{node['fqdn']} --server-url https://#{current_chef_server}#{node['linux']['chef']['chef_org']} -c /etc/chef/client.rb --user #{node['linux']['chef']['bootstrap_user']} -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}-#{current_chef_server}.pem -y
          knife client delete #{node['fqdn']} --server-url https://#{current_chef_server}#{node['linux']['chef']['chef_org']} -c /etc/chef/client.rb --user #{node['linux']['chef']['bootstrap_user']} -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}-#{current_chef_server}.pem -y
          rm -f /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem
          rm -f /etc/chef/#{node['linux']['chef']['bootstrap_user']}-#{current_chef_server}.pem
          '>/dev/null 2>&1 &
      EOF
      sensitive node['linux']['runtime']['sensitivity']
    end

    template '/etc/chef/client.rb' do
      source 'etc/chef/client.rb.erb'
      owner 'root'
      group 'root'
      mode 0600
      action :create
      sensitive node['linux']['runtime']['sensitivity']
      variables(
        fqdn: node['fqdn'],
        chefsvr: node['linux']['chef']['new_chef_server']
      )
    end
  end
end
