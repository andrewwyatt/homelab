![Homelab](../../logo.png)

# Enterprise Linux Cookbook

## About


This cookbook configures and manages a standardized, and reasonably hardened
Linux server.  It is integrated with Slack, the recipes and scripts contained within will notify a defined channel of events taking place under the scope of system management if configured.

See the [recipes](./recipes) and [attributes](./attributes) for more detail of the objects managed by this cookbook.

**NOTICE** *These cookbooks do not have a default.rb, this is intentional.  Use wrapper
cookbooks to consume the recipes instead.  See the provisioned_services cookbook and
the readme in the root of this project for more information.*

**WARNING:** *These cookbooks should not be used for production without additional modification.*

**WARNING** *The decom and rebuild recipes are destructive, they will
decommission and destroy a node as soon as the node checks into the Chef server.
This includes removing the node from AD, deleting the node's DNS records,
removing it from Chef, deleting the partition table, and powering it down or
rebooting it.*

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
