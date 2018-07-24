name             'provisioner'
maintainer       'Andrew Wyatt'
maintainer_email 'andrew@fuduntu.org'
license          'Apache-2.0'
description      'Installs and configures a local CentOS mirror, provides a package building service, and facilitates network OS installs.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.5.1'
chef_version     '>= 12.1' if respond_to?(:chef_version)
depends          'enterprise_linux'
supports         'redhat'
source_url       'https://github.com/andrewwyatt/tilde-slash-lab'
issues_url       'https://github.com/andrewwyatt/tilde-slash-lab/issues'
