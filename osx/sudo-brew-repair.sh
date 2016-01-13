#!/bin/bash

## Repair Homebrew permissions in some places:
echo " * Repairing homebrew (it's fails sometimes)";
sudo chown -R $(whoami) /usr/local/lib/pkgconfig;
sudo chown -R $(whoami) /usr/local/sbin;
sudo chown -R $(whoami) /usr/local/share/locale;