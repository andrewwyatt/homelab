name             'enterprise_linux'
maintainer       'Andrew Wyatt'
maintainer_email 'andrew@fuduntu.org'
license          'Apache-2.0'
description      'Basic enterprise linux server configuration cookbook'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.5.3'
chef_version     '>= 12.1' if respond_to?(:chef_version)
supports         'redhat'
source_url       'https://github.com/andrewwyatt/homelab'
issues_url       'https://github.com/andrewwyatt/homelab/issues'
