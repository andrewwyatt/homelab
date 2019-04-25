###
### Cookbook:: chef
### Recipe:: configure_mirroring
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
### The encrypted payload password is stored in credentials -> passwords
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
  backup false
  sensitive true
  action :nothing
end

openssl_decrypt = String.new("openssl aes-256-cbc -a -d -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")
openssl_encrypt = String.new("openssl aes-256-cbc -a -salt -pass file:#{Chef::Config[:file_cache_path]}/.#{passfile}")

unless node['chef']['sync_host'] == node['fqdn']
  if tagged?(node['chef']['master_tag'])
    untag(node['chef']['master_tag'])
  end
  tag(node['chef']['worker_tag'])
  if node['chef']['sync'] == true
    directory node['chef']['mirror_root'] do
      owner 'root'
      group 'root'
      mode '0700'
      recursive true
      action :create
    end
    node['chef']['organizations'].each do |key,org|

      directory node['chef']['mirror_root'] do
        owner 'root'
        group 'root'
        mode 0700
        action :create
      end

      directory "#{node['chef']['mirror_root']}/#{node['chef']['sync_host']}" do
        owner 'root'
        group 'root'
        mode 0700
        action :create
      end

      directory "#{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/#{org['short_name']}" do
        owner 'root'
        group 'root'
        mode 0700
        action :create
      end

      directory "#{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/#{org['short_name']}/data" do
        owner 'root'
        group 'root'
        mode 0700
        action :create
      end

      remote_file "#{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/pivotal.pem.enc" do
        source "https://#{node['chef']['sync_host']}#{node['chef']['bootstrap_root']}pivotal.pem.enc"
        owner 'root'
        group 'root'
        mode 0640
        sensitive node['chef']['runtime']['sensitivity']
        action :create
      end

      notification = "Decrypt the pivotal key for replication."
      bash notification do
        code <<-EOF
          #{openssl_decrypt} -in #{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/pivotal.pem.enc -out #{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/pivotal.pem
        EOF
        notifies :create, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :before
        notifies :delete, "file[#{Chef::Config[:file_cache_path]}/.#{passfile}]", :delayed
        sensitive node['chef']['runtime']['sensitivity']
      end

      hosts = [ node['chef']['sync_host'],
                node['fqdn'] ]

      hosts.each do | host |
        template "#{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/#{org['short_name']}/#{host}.rb" do
          source 'mirror/client.rb.erb'
          owner 'root'
          group 'root'
          mode 0700
          sensitive node['chef']['runtime']['sensitivity']
          action :create
          variables({
            mirror_root:         node['chef']['mirror_root'],
            chef_server:         host,
            chef_org:            org['short_name']
          })
        end
        execute "Fetching certificates from #{host}" do
          command "knife ssl fetch -c #{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/#{org['short_name']}/#{host}.rb 2>/dev/null"
          action :run
          sensitive node['chef']['runtime']['sensitivity']
        end
      end

      node['chef']['mirror'].each do | dataset |
        execute "Fetching data from #{node['chef']['sync_host']}" do
          command "knife download /#{dataset} --chef-repo-path #{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/#{org['short_name']}/data -c #{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/#{org['short_name']}/#{node['chef']['sync_host']}.rb"
          sensitive node['chef']['runtime']['sensitivity']
        end
        execute "Uploading data to #{node['fqdn']}" do
          command "knife upload /#{dataset} --chef-repo-path #{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/#{org['short_name']}/data -c #{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/#{org['short_name']}/#{node['fqdn']}.rb -k /etc/opscode/pivotal.pem"
          sensitive node['chef']['runtime']['sensitivity']
        end
      end

      cleanup = [ "#{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/pivotal.pem",
                  "#{node['chef']['mirror_root']}/#{node['chef']['sync_host']}/pivotal.pem.enc",
                  "#{node['fqdn']}.rb",
                  "#{node['chef']['sync_host']}.rb" ]

      cleanup.each do | cfile |
        file cfile do
          action :delete
        end
      end
    end
  end
else
  if tagged?(node['chef']['worker_tag'])
    untag(node['chef']['worker_tag'])
  end
  tag(node['chef']['master_tag'])
end
