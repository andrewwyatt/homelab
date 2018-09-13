![Homelab](logo.png)

## About

This repository contains a set of cookbooks that I use to manage my home lab.  They provide a suite of capabilities that allow systems to automatically provision and also be destroyed and replaced very quickly allowing me to rapidly deploy and test new software and technologies.

* Configures Chef server in a single instance or downstream replica configuration.
* Implements PXE deployment services (just create a VM and turn it on).
* Provisions and manages RPM building and hosting services.
* Provisions and manages CentOS mirror servers.
* Integrates server and Chef authentication with JumpCloud for access and authorization, with Zonomi for DNS, and with Let's Encrypt for SSL.
* Hardens managed servers, and maintains the hardening specification.
* Notifies a slack channel of critical and non-critical events.
* Configures and enforces desired state.

**WARNING:** *These cookbooks should not be used for production without additional modification.*

## License

Copyright 2013-2018, Andrew Wyatt

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Wrapper Cookbook Functions
The cookbooks in this project do not have default recipes, and that is by design.  They should only be used as part of a wrapper cookbook model.  Example wrapper cookbooks are included in the project.  They are defined as follows.

### lab_management::chef\_server

    Node Name: cdc0001.{DOMAIN}
    Function: Provisions a managed Chef server.

### lab_management::provisioning\_server

    Node Name: cdc0002.{DOMAIN}
    Function: Mirrors CentOS and local builders.
              Builds and signs source and binary RPMs.
              Deploys and configures Cobbler to automatically build managed servers.

### lab_management::migrate\_self\_to\_{SERVER}

    Node Name: Any
    Function: Migrates a server from one Chef instance to another.

### lab_management::rebuild\_self

    Node Name: Any
    Function: Destroy and rebuild the node that the recipe is assigned on the next Chef check-in.

### lab_management::decommission\_self

    Node Name: Any
    Function: Destroy and shutdown the node that the recipe is assigned on the next Chef check-in.

**Note:** *The lab management recipes have a specific inheritance order making it necessary to remove the lab_management::standard\_server recipe from your node roles when using them due to conflicts.  These recipes already include the standard_server recipe.*

## Installation

Building a test lab with Chef is simplified using these cookbooks.  They require the following configuration.

* An ESXi host
* An account set up at JumpCloud (see below)
* An account set up with Zonomi (see below)
* Build the system definitions listed at the bottom of the README manually, or by using the kickstart data in the ks directory

## Operating System Support

The code to provision the home lab supports the following enterprise Linux distributions.  

* CentOS 7

## Lab Server System Requirements (Minimum)

### Chef servers

* 4 vCPU
* 4GB vRAM
* 10GB OS
* 70GB /var (or /var/opt)

### Provisioning servers

* 2 vCPU
* 2GB vRAM
* 10GB OS
* 100GB /var (or /var/www)

### General lab servers (minimum)

* 1 vCPU
* 2GB vRAM
* 10GB OS

## Configuring the first Chef server instance (Master)

The first Chef instance will need to be provisioned manually.  The steps below will set up the initial instance of Chef server, and once the Chef Server cookbook is applied the server will begin managing itself.

### First generate keys for Chef (Optional)
This is an optional step to set up the SSL certificates for Chef.  You may skip it if you want to use self signed certificates, or you are using Zonomi for DNS and have the Chef cookbook configured to use ACME/Let's Encrypt. The Chef server cookbook will provision the certificates from Let's Encrypt or the Chef server will provision self signed certs on first run.

1. Generate an SSL certificate if required for Chef from LetsEncrypt or your certificate authority of choice. Wildcard certs are preferred.
2. Create the /etc/opscode directory.
3. Copy the crt and the pem to /etc/opscode and name them {FQDN}.[crt,pem]

Add the keys to the /etc/opscode/chef-server.rb before running the first reconfigure (below).

    nginx['ssl_certificate'] = "/etc/opscode/{FQDN}.crt"
    nginx['ssl_certificate_key'] = "/etc/opscode/{FQDN}.pem"

### Now update the Chef cookbook attributes

In order to provision a Chef server we need to ensure a few things.  The Chef server cookbook utilizes many attributes to provide data to the cookbook while also allowing the cookbook to be configured dynamically via Environment and Role.  To familiarize with the attributes in use, review and update cookbooks/chef/attributes/default.rb to suit your environment.

### Next install the Chef server

1. Install the chef-server-core package from [Chef](https://downloads.chef.io/chef-server).
2. Create /etc/opscode/chef-server.rb.

		ldap['base_dn'] = 'ou=Users,o={YOUR JUMPCLOUD ORG},dc=jumpcloud,dc=com'
		ldap['bind_dn'] = 'uid=chef_authenticator,ou=Users,o={YOUR JUMPCLOUD ORG},dc=jumpcloud,dc=com'
		ldap['host'] = 'ldap.jumpcloud.com'
		ldap['enable_tls'] = 'true'
		ldap['port'] = '389'
		ldap['login_attribute'] = 'uid'
		nginx['ssl_protocols'] = 'TLSv1.1 TLSv1.2'
		### Comment the certificates if using self signed.
		nginx['ssl_certificate'] = "/etc/opscode/{FQDN}.crt"
		nginx['ssl_certificate_key'] = "/etc/opscode/{FQDN}.pem"

3. Configure the Chef server.

        # chef-server-ctl reconfigure
        # chef-server-ctl restart opscode-erchef

4. Create the directory to store the keys created during this process.

        # mkdir /etc/opscode/keys

5. Add the administrative account to Chef.

        # chef-server-ctl user-create admin System Admin {EMAIL ADDRESS} '{RANDOM}' -f /etc/opscode/keys/admin.pem

6. Create an organization, and add the administrative user.

        # chef-server-ctl org-create {ORG} {ORG Name} --association_user admin -f /etc/opscode/keys/{ORG}-validator.pem

7. Generate an encrypted data bag secret key.

        # openssl rand -base64 512 | tr -d '\r\n' >/etc/opscode/keys/encrypted_data_bag_secret

8. Copy the secret key to /etc/Chef.

        # cp /etc/opscode/keys/encrypted_data_bag_secret /etc/chef

9. Install the Chef client on the server using the package from (Chef)[https://downloads.chef.io/chef].

10. Create /etc/chef/client.rb pointing the server to itself.

        current_dir              = File.dirname(__FILE__)
        log_level                :info
        log_location             STDOUT
        node_name                "{FQDN}"
        chef_server_url          "https://{FQDN}/organizations/{ORG}"
        cache_type               "BasicFile"
        cache_options( :path =>  "#{ENV['HOME']}/.chef/checksums" )
        ohai.plugin_path         << '/etc/chef/ohai/plugins'

11. Bootstrap the Chef server to itself.

        # chef-client -S https://$(hostname -f)/organizations/{ORG} -K /etc/opscode/keys/{ORG}-validator.pem -c /etc/chef/client.rb

12. Install the Chef manage package using chef-server-ctl.

        # chef-server-ctl install chef-manage

13. Create /etc/chef-manage/manage.rb with the following parameters.

        org_creation_enabled false
        disable_sign_up true

14. Reconfigure Chef Manage.

        # chef-manage-ctl reconfigure

15. Log into Chef manage with your AD credentials and request an invitation.
16. Approve the request with chef-server-ctl.

        # chef-server-ctl org-user-add {ORG} {USERNAME} --admin

17. Log into Chef manage with your Chef account, and reset your private key (unless you saved it).

18. Set up knife using [knifecfg](https://github.com/andrewwyatt/knifecfg) and create the Chef server data bag using the template above.

        # export EDITOR=vim
        # knife data bag create credentials chef_server --secret-file=~/.chef/encrypted_data_bag_secret

19. Upload the cookbooks to the Chef server

        # knife cookbook upload chef enterprise_linux provisioner lab_management -o {path to the cookbooks}

20. Create an environment in Chef called '{ORG}'
21. Assign the Chef server to the {ORG} environment.
22. The role for the Chef server should be the servers FQDN with the periods changed to underbars.

    * Ex. cdc0001.{DOMAIN} -> cdc0001_lab_fewt_com
    * Add the lab\_management::chef\_server recipe to the role.

23. Apply the role to the Chef server.
24. Run chef-client on the Chef server to complete provisioning.

The Chef server should now be managing itself, run Chef client again to verify.

## Configuring additional Chef server instances

Configuring additional instances is simple once the first instance is online.  To bring up a worker instance, perform the following steps after generating SSL keys for each server.

1. Deploy a virtual machine matching the specs for a Chef server
2. On the master server, add the lab_management::chef\_server role to the server's auto-generated primary role.

The system should provision itself with Chef, and then download all of the environments, roles, data bags, and cookbooks from Chef instance it is connected too.  The default behavior is to sync every time the Chef client executes on the node.  This behavior will continue with Chef instances connected to these Chef instances and downstream instances of those as well.

    Master Chef server (001) -> Secondary Chef server (002) -> Tertiery Chef server (004)
                             -> Secondary Chef server (003) -> Tertiery Chef server (005)
                             <- Replicates from (001)       <- Replicates from (002 or 003)

## Bootstrapping Linux Clients manually

New servers are added to Chef automatically, but if there is a need to add a server manually, it is pretty simple.

1. From the client you would like to bootstrap to Chef, download the bootstrap tool from the upstream Chef server you want the server to connect too.

        # curl -o bootstrap https://{Chef Server FQDN}/node/bootstrap [--insecure]

2. Execute the script with the necessary options to remove the existing Chef client data, and connect it to the upstream Chef server instance.

        # bash bootstrap -t 0 -c

3. Enter the bootstrap passphrase when asked.  This is required to decrypt the encrypted keys needed to connect the host to the Chef server.
4. Once complete, apply the desired roles and recipes to the servers primary role.

## Cookbook Data Bags

To consume the Chef cookbooks under this project, multiple data bags must be created in addition to the bag created in an earlier step.  These data bags should exist under the "Credentials" bag.

### Credentials / passwords

This bag contains the basic credentials necessary to configure servers in the environment with Chef.  Passwords should be a minimum of 16 characters, mixed case letters, numbers, and symbols.

    {
      "id": "passwords",
      "bootstrap_passphrase": "{Random Passphrase}",
      "root_hash": "{Root Hash}",
      "grub2_hash": "GRUB2_PASSWORD={GRUB2 Hash}",
      "sasl_passwd": "{SASL Password}",
      "jumpcloud_api": "{JumpCloud API key}",
      "jumpcloud_connect": "{JumpCloud Connect key}",
      "monit_password": "{Random monit password)",
      "zonomi_api": {Zonomi API key}",
      "automate_token": "{Automate Token}"
    }

#### bootstrap\_passphrase

This cookbook adds a feature to Chef servers adding the ability to bootstrap new clients directly from itself.  This is the password that is used to encrypt and decrypt the package used by the feature. It should be randomized.

#### root\_hash

This is the root password hash that is applied to the root account on all managed servers.  You can generate a SHA512 password hash using Python.

    python -c 'import crypt,getpass; print(crypt.crypt(getpass.getpass(), crypt.mksalt(crypt.METHOD_SHA512)))'

#### grub2\_hash

This configures the grub password, making it required for accessing servers.  It should contain the GRUB2_PASSWORD= key prefix.  It can be created using grub2-setpassword.

    # grub2-setpassword
    # cat /boot/grub2/user.cfg
    
Copy the entire content of /boot/grub2/user.cfg.

### sasl\_passwd

This is the relay and password data needed to configure postfix for SASL email relay.  The format for this attribute is as follows:

    [relay]:port username:password

#### jumpcloud\_api

This is the API key for accessing the JumpCloud API.

#### jumpcloud\_connect

This is the connect key used for adding hosts to JumpCloud.

#### monit\_password

This is the password for the monit service http admin account.

#### zonomi\_api

This is the API key used to connect to Zonomi for DNS record management.

#### auth\_user

This entry contains the password for the Chef service account used for authentication to Chef manage.

#### automate_token

This defines the automate token used to authenticate Chef clients and server to an Automate instance.

### Credentials / {PROVISIONER\_USER}

This bag contains credentials needed to create and sign RPM packages.

    {
      "id": "builder",
      "rpmmacros": "{RPM MACROS FILE CONTENT}",
      "signing_passphrase": "{SIGNING PASSPHRASE}",
      "private_key": "{SIGNING PRIVATE KEY}",
      "public_key": "{SIGNING PUBLIC KEY}",
      "gpgid": "{KEY GPG ID}"
    }

#### rpmmacros

This item should contain the content of the .rpmmacros file.  An example is provided below.

    %_signature gpg
    %_gpg_name {HEX}

#### Signing Passphrase

This is the passphrase used by the GPG key defined in the rpmmacros to sign packages that are built or imported by the builder.

#### private\_key

The private key configured on the packaging server used to sign packages.

    $ gpg --gen-key

#### public\_key

This is the public key that will be hosted in the mirror for servers to authenticate against during package installation.

#### gpgid

The gpgid variable is used by the builder recipe to track the keys.

## Provisioners

Prior to configuring the provisioners, set the local repository attribute to disabled.  Once everything is configured, and chef client has been run on all nodes successfully it is OK to turn this back on.

## Zonomi Configuration

Create an account for your lab domain at Zonomi.  The API key to add to the encrypted data bag can be found on the [DNS API help](https://zonomi.com/app/dns/dyndns.jsp) page.

## JumpCloud Configuration

Create an account for domain at JumpCloud.  You will need the following to configure the cookbook:

### User Accounts

* Chef Authenticator with LDAP Bind enabled
* User Access Accounts

### User Groups

* Chef Admins (chef-admins)
* Chef Users (chef-users)
* Domain Admins (domain-admins)
* Domain Users (domain-users)

Configuration of the Chef recipe requires the JumpCloud group ids, using the group names will result in errors.  To get the group names, use the [JumpCloud API documentation](https://docs.jumpcloud.com/2.0/user-groups/list-all-users-groups) to find the GIDs for your groups.

### System Groups

* Servers

Configuration of the Enterprise Linux recipe requires the Servers group id.  Use the [JumpCloud API documentation](https://docs.jumpcloud.com/2.0/system-groups/list-all-systems-groups) to find the GID for your group.

### Chef Configuration

JumpCloud is configured by Chef via the enterprise_linux::jumpcloud recipe.  In order to use this recipe, the following needs to be configured in Chef.

* The JumpCloud Connect key (Add to the credentials -> passwords data bag)
* The JumpCloud API key (Add to the credentials -> passwords data bag)
* The GroupID of the servers system group (found via [API query](https://docs.jumpcloud.com/2.0/system-groups/list-all-systems-groups))

Servers will automatically install the JCAgent software, and add themselves to the Servers sytem group.  When decommissioning using the decom recipe, they will remove themselves before powering down or restarting.

## Adding nodes

Systems will auto provision to the profile set by default.  If you would like to manually configure the profile deployed to nodes you should add them to cobbler manually.

### Chef Master Server

* **Roles:** lab\_chef\_server
* **CNAMES:** chef.{DOMAIN}

        cobbler system add --name cdc0001.{DOMAIN} --hostname cdc0001.{DOMAIN} \
                           --profile CentOS-7-x86_64 --interface ens192        \
                           --mac-address {MAC_ADDRESS}

### Provisioning Server

* **CNAMES:** mirror.{DOMAIN}, build7.{DOMAIN}, deploy.{DOMAIN}

        cobbler system add --name cdc0002.{DOMAIN} --hostname cdc0002.{DOMAIN} \
                           --profile CentOS-7-x86_64 --interface ens192        \
                           --mac-address {MAC_ADDRESS}
