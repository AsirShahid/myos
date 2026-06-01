#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Install the Nix package manager in multi-user (daemon) mode.
echo 'Installing Nix...'
sh <(curl -L https://nixos.org/nix/install) --daemon
echo 'Nix installed'
