#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Enable the Pop Shell GNOME extension.
echo 'Enabling pop-shell GNOME extension...'
gnome-extensions enable pop-shell@system76.com
