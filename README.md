# ~/Lab, Managed by Chef

## About

This repository contains a suite of cookbooks that I use to manage my home lab.  They provide a suite of capabilities that allow systems to automatically provision and also be destroyed and replaced very quickly allowing me to rapidly deploy and test new software and technologies.

### This project enables

* Configuring Chef server in a single instance or downstream replica configuration.
* PXE deployment servers (just create a VM and turn it on)
* Provisioning and managing RPM building and hosting servers.
* Provisioning and managing CentOS mirror servers.
* Integrating managed servers with AD for access and authorization
* Hardening managed servers to be nearly CIS 1 compliant.
* Configuring and enforcing desired state
* Replicate environments, databags, roles, and cookbooks.

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

### lab_management::mirror\_server

    Node Name: cdc0002.{DOMAIN}
    Function: Mirrors CentOS and local builders.

### lab_management::package\_builder

    Node name: cdc0003.{DOMAIN}
    Function: Builds and signs source and binary RPMs.

### lab_management::node\_builder

    Node Name: cdc0004.{DOMAIN}
    Function: Deploys and configures Cobbler to automatically build managed servers.

### lab_management::move\_node\_to\_{SERVER}

    Node Name: Any
    Function: Migrates a server from one Chef instance to another.

### lab_management::rebuild\_server

    Node Name: Any
    Function: Destroy and rebuild the node that the recipe is assigned.

### lab_management::decom\_server

    Node Name: Any
    Function: Destroy and shutdown the node that the recipe is assigned.


## Installation

Building a test lab with Chef is simplified using these cookbooks.  They require the following configuration.

* An ESXi host
* One or more MSAD domain controllers (cdw0001.{DOMAIN}, cdw0002.{DOMAIN})
* Build the system definitions listed at the bottom of the README manually, or by using the kickstart data in the ks directory
* Install the [Centrify RPMs](https://www.centrify.com/express/linux-unix/download-files/) on each of the servers created.
* In AD, create CNAMES for each server.

## Operating System Support

The code to provision the home lab supports the following enterprise Linux distributions.  

* CentOS 7
* CentOS 6 (deprecated)

It is untested on other RPM based distributions, and is completely incompatible with non-RPM based Linux distributions.  CentOS 6 support still exists in the sources, but it is no longer used and may be removed in the future.

## Lab Server System Requirements (Minimum)

### Chef servers

* 4 vCPU
* 4GB vRAM
* 30GB OS
* 60GB /var/opt
* 20GB /opt

### Package build servers

* 2 vCPU
* 2GB vRAM
* 30GB OS

### Mirror servers

* 2 vCPU
* 2GB vRAM
* 30GB OS
* 100GB /var/www

### OS deployment servers

* 2 vCPU
* 2GB vRAM
* 30GB OS
* 10GB /var/www

## Configuring the first Chef server instance (Master)

The first Chef instance will need to be provisioned manually.  The steps below will set up the initial instance of Chef server, and once the Chef Server cookbook is applied the server will begin managing itself.

### First generate keys for Chef (Optional)

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

        ldap['base_dn'] = '{DOMAIN DN}'
        ldap['bind_dn'] = '{AD CHEF SERVICE ACCOUNT DN)'
        ldap['host'] = '{DOMAIN}'
        ldap['enable_tls'] = 'true'
        ldap['port'] = '389'
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
        cookbook_path            ["#{current_dir}/../cookbooks"]
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
    * Add the lab\_management::lab\_build and lab\_management::chef\_server recipes to the role.

23. Apply the role to the Chef server.
24. Run chef-client on the Chef server to complete provisioning.
25. Once provisioning is complete, remove the lab\_build role and apply lab\_management::standard\_node in its place.

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

This bag contains the basic credentials necessary to configure servers in the environment with Chef.

    {
      "id": "passwords",
      "bootstrap_passphrase": "{RANDOM PASSPHRASE}",
      "root_hash": "{ROOT HASH}",
      "sasl_passwd": "{SASL PASSWORD}",
      "cobbler": "{COBBLER_ROOT_HASH}",
      "ad_bind_account": "{CHEF_SERVICE_ACCOUNT_PASSWORD}",
      "automate_token": "{AUTOMATE TOKEN}"
    }

#### bootstrap\_passphrase

This cookbook adds a feature to Chef servers adding the ability to bootstrap new clients directly from itself.  This is the password that is used to encrypt and decrypt the package used by the feature. It should be randomized.

#### root\_hash

This is the root password hash that is applied to the root account on all managed servers.

### sasl\_passwd

This is the relay and password data needed to configure postfix for SASL email relay.  The format for this attribute is as follows:

    [relay]:port username:password

#### cobbler

This is the password hash that is applied to the kickstart used to provision servers.

#### ad\_bind\_account

This entry contains the password for the Chef service account used for authentication to Chef manage.

#### automate_token

This defines the automate token used to authenticate Chef clients and server to an Automate instance.

### Credentials / centrify

This bag contains the credentials needed to join computers and manage DNS records.

    {
      "id": "centrify",
      "{DOMAIN_USER}": "{DOMAIN_PASSWORD}"
    }

### DOMAIN\_USER

Set this to the domain service account used to manage computer and DNS objects in the domain.

### Credentials / certificates

Only necessary if using genuine host or wildcard certificates.

    {
      "id": "certificates",
      "{FQDN}-crt": "Certificate data for HOST",
      "{FQDN}-key": "Private key data for HOST certificate",
      "{DOMAIN}-crt": "Certificate data for DOMAIN (Wildcard)",
      "{DOMAIN}-key": "Private key data for DOMAIN certificate"
    }

#### {FQDN}-crt

If you're using a signed host certicate, this item should contain the content of that certificate.

#### {FQDN}-key

If you're using a signed host certicate, this item should contain the content of that certificate's private key.


#### {DOMAIN}-crt

If you're using a signed wildcard certicate, this item should contain the content of that certificate.

#### {DOMAIN}-key

If you're using a signed wildcard certicate, this item should contain the content of that certificate's private key.

### Credentials / {PROVISIONER\_USER}

This bag contains credentials needed to create and sign RPM packages.

    {
      "id": "builder",
      "rpmmacros": "{RPM_MACROS_FILE}",
      "signing_passphrase": "{SIGNING_PASSPHRASE}",
      "private_key": "{SIGNING_PRIVATE_KEY}",
      "public_key": "{SIGNING_PUBLIC_KEY}",
      "gpgid": "{KEY_GPG_ID}"
    }

#### rpmmacros

This item should contain the content of the .rpmmacros file.  An example is provided below.

    %_signature gpg
    %_gpg_name {HEX}

#### Signing Passphrase

This is the passphrase used by the GPG key defined in the rpmmacros to sign packages that are built or imported by the builder.

#### private\_key

The private key configured on the packaging server used to sign packages.

#### public\_key

This is the public key that will be hosted in the mirror for servers to authenticate against during package installation.

#### gpgid

The gpgid variable is used by the builder recipe to track the keys.

## Provisioners

Prior to configuring the provisioners, set the local repository attribute to disabled.  Once everything is configured, and chef client has been run on all nodes successfully it is OK to turn this back on.

## Domain Configuration
### DC Time Sync

Configure each DC to use an external time source.

    w32tm /config /computer:ulcdw0001.{DOMAIN} /manualpeerlist:time.windows.com /syncfromflags:manual /update

    w32tm /config /computer:ulcdw0002.{DOMAIN} /manualpeerlist:time.windows.com /syncfromflags:manual /update

### DC User accounts

Create an account for joining the domain, and grant delegation to create and destroy computer accounts.  Also grant access as a DNS admin for DNS (de)provisioning.

## Adding nodes

Systems will auto provision to the profile set by default.  If you would like to manually configure the profile deployed to nodes you should add them to cobbler manually.

### Chef Master Server

* **Roles:** enterprise\_linux, lab\_chef\_server
* **CNAME:** chef.{DOMAIN}

        cobbler system add --name cdc0001.{DOMAIN} --hostname cdc0001.{DOMAIN} \
                           --profile CentOS-7-x86_64 --interface eth0          \
                           --mac-address {MAC_ADDRESS}

### OS Mirror Server

* **Roles:** enterprise\_linux, lab\_mirror\_builder
* **CNAME:** mirror.{DOMAIN}

        cobbler system add --name cdc0002.{DOMAIN} --hostname cdc0002.{DOMAIN} \
                           --profile CentOS-7-x86_64 --interface eth0          \
                           --mac-address {MAC_ADDRESS}

### EL7 RPM Build Server

* **Roles:** enterprise\_linux, lab\_package\_builder
* **CNAME:** build7.{DOMAIN}

        cobbler system add --name cdc0003.{DOMAIN} --hostname cdc0003.{DOMAIN} \
                           --profile CentOS-7-x86_64 --interface eth0          \
                           --mac-address {MAC_ADDRESS}

### OS Provisioning Server

* **Roles:** enterprise\_linux, lab\_node\_builder
* **CNAME:** deploy.{DOMAIN}

        cobbler system add --name cdc0004.{DOMAIN} --hostname cdc0004.{DOMAIN} \
                           --profile CentOS-7-x86_64 --interface eth0          \
                           --mac-address {MAC_ADDRESS}
