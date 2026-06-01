#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Install the build/runtime dependencies for AGS (Aylur's GTK Shell):
# JS tooling, the matugen color generator, and the Material You Python libs.
echo 'Installing AGS dependencies...'
sudo npm -g install bun
#curl -fsSL https://bun.sh/install | bash
sudo npm -g install sass
cargo install matugen
pip3 install materialyoucolor --upgrade
pip3 install material-color-utilities-python --upgrade
pip3 install build --upgrade
pip3 install 'pillow<10.0.0,>=9.2.0' --upgrade
pip3 install pywal --upgrade
pip3 install wheel --upgrade
pip3 install setuptools-scm --upgrade
