#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Your code goes here.
echo 'This is an example shell script'
echo 'Scripts here will run during build if specified in recipe.yml'
wget https://download.beeper.com/linux/appImage/x64
chmod a+x ./x64
mv x64 beeper
mv beeper /usr/bin/
