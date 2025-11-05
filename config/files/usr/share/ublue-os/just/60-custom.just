# vim: set ft=make :
# Custom commands for your Bluefin+Bazzite hybrid

# Your custom AGS dependencies installation
ags-deps:
    sudo npm -g install bun
    sudo npm -g install sass
    brew install sass/sass/sass
    cargo install matugen
    pip3 install materialyoucolor --upgrade
    pip3 install material-color-utilities-python --upgrade
    pip3 install build --upgrade
    pip3 install 'pillow<10.0.0,>=9.2.0' --upgrade
    pip3 install pywal --upgrade
    pip3 install wheel --upgrade
    pip3 install setuptools-scm --upgrade

# Add any other custom commands you want here
# Don't duplicate commands from 10-update.just or bluefin-*.just
