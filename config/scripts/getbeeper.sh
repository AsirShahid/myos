#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Download and install Beeper for Linux
echo 'Downloading Beeper for Linux...'
wget -O beeper https://api.beeper.com/desktop/download/linux/x64/stable/com.automattic.beeper.desktop
chmod a+x ./beeper
mv beeper /usr/bin/
echo 'Beeper installation completed'
