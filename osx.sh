#!/bin/bash
#####
# OS X configuration script entry point here.
#
# (tested on El Capitan 10.11.2)
# (first appears since Lion 10.7.5)
#
# (c) Sergey S Petrenko 2012-2016
#
# If you are not me check out latest version on GitHub
#
# Read README.md for details
#
# No license applied: use it as you want
# but everything is on your own responsibility.
#

## Making bash more strict to what happens
# Let unset variable usage is an error (hello, JS!)
set -u
# And let script immediately killed itself on any error
set -e
bash osx/000-preinstall.sh
bash osx/001-root-changes.sh
npm install;
cd osx && node 002-setup.js
