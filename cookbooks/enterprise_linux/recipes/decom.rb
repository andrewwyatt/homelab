###
### Cookbook Name:: enterprise_linux
### Recipe:: decom
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

passfile = Random.rand(99999999) * Random.rand(99999999) * Random.rand(99999999)
file "#{Chef::Config[:file_cache_path]}/.#{passfile}" do
  owner 'root'
  group 'root'
  mode 0600
  content passwords['bootstrap_passphrase']
  sensitive true
  action :nothing
end

openssl_decrypt = String.new("openssl aes-256-cbc -a -d -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")
openssl_encrypt = String.new("openssl aes-256-cbc -a -salt -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")

node.default['linux']['chef']['server']=`printf $(grep chef_server_url /etc/chef/client.rb  | sed -s -e "s#^.*//##" -e "s#/.*\\\$##")`

notification=node['linux']['decom']['decom_notice']
bash "Send decom notice" do
  code <<-EOF
    ### user channel emoji api_key message
    notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end

if File.exists?("/opt/jc/jcagent.conf")
  localdata = `cat /opt/jc/jcagent.conf 2>/dev/null`

  if localdata.length < 1
    localdata = "{}"
  end

  lattrs = JSON.parse(localdata)
  lattrs = Hash[*lattrs.collect{|h| h.to_a}.flatten]

  bash "Ensuring #{node['fqdn']} is removed from JumpCloud." do
    code <<-EOF
      curl -X DELETE "#{node['linux']['jumpcloud']['api_url']}/systems/#{lattrs['systemKey']}" \
           -H 'Accept: application/json'                \
           -H 'Content-Type: application/json'          \
           -H 'x-api-key: #{passwords['jumpcloud_api']}'
    EOF
    sensitive node['linux']['runtime']['sensitivity']
  end
end


remote_file "#{Chef::Config['file_cache_path']}/#{node['linux']['chef']['bootstrap_user']}.pem.enc" do
  source "https://#{node['linux']['chef']['server']}#{node['linux']['chef']['bootstrap_root']}#{node['linux']['chef']['bootstrap_user']}.pem.enc"
  owner 'root'
  group 'root'
  mode 0600
  action :create
  sensitive node['linux']['runtime']['sensitivity']
end

execute 'Configure the admin key' do
  command "#{openssl_decrypt} -in #{Chef::Config['file_cache_path']}/#{node['linux']['chef']['bootstrap_user']}.pem.enc -out /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem"
  action :run
  notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
  sensitive node['linux']['runtime']['sensitivity']
end

### Remove my partition table
notification="Removing my partition table"
bash "Flushing my partition table" do
  code <<-EOF
    notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
    dd if=/dev/zero of=/dev/sda bs=512 count=1
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end

node_role = String.new
node_role = node['fqdn'].gsub(".", "_")

notification="Deleting myself from Chef server #{node['linux']['chef']['server']}."
bash "Remove myself from Chef, and power down." do
  code <<-EOF
    notify "#{node['fqdn']}" "#{node['linux']['slack_channel']}" "#{node['linux']['emoji']}" "#{node['linux']['api_path']}" "#{notification}"
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

      ### Have to wait for Chef client to complete or it will clobber the node deletion
      knife role delete #{node_role} -c /etc/chef/client.rb -y -u #{node['linux']['chef']['bootstrap_user']} -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem
      knife node delete #{node['fqdn']} -c /etc/chef/client.rb -y -u #{node['linux']['chef']['bootstrap_user']} -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem
      knife client delete #{node['fqdn']} -c /etc/chef/client.rb -y -u #{node['linux']['chef']['bootstrap_user']} -k /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem
      rm -f /etc/chef/#{node['linux']['chef']['bootstrap_user']}.pem
      ### Wait for the system record to be destroyed before completing the task.
      while [ true ]
      do
        check=$(curl "http://#{node['linux']['cobbler']['server']}/cblr/svc/op/ks/system/#{node['fqdn']}" 2>/dev/null)
        if [ "${check}" = "# system not found" ]
        then
          break
        fi
        sleep 5
      done
      #{node['linux']['decom']['final_task']}' >/dev/null 2>&1 &
  EOF
  sensitive node['linux']['runtime']['sensitivity']
end
