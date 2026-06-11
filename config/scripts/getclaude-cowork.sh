#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Stage claude-cowork-linux into the image.
#
# claude-cowork-linux runs Claude Desktop's Cowork mode natively on Linux.
# Its install/launch flow is per-user and runtime-driven (it downloads
# Anthropic's proprietary Claude Desktop DMG into the user's home), so we do
# NOT bake the app itself into the image. Instead we bake the dependencies and
# the upstream source, and ship a launcher (/usr/bin/claude-cowork) that
# bootstraps the install into the user's writable home on first run.

echo 'Staging claude-cowork-linux...'

# Node global tools the upstream launcher needs: electron + @electron/asar.
# During the BlueBuild build /usr is writable, so `npm -g` lands in the image
# (binaries symlinked into /usr/bin), keeping them on PATH at runtime where
# /usr is read-only.
npm install -g @electron/asar electron

# Clone the upstream source read-only into the image. The launcher mirrors
# this into ~/.local/share at runtime (same strategy as the upstream Nix flake).
rm -rf /usr/share/claude-cowork-linux
git clone --depth=1 https://github.com/johnzfitch/claude-cowork-linux.git /usr/share/claude-cowork-linux
# Drop the upstream .git to keep the image lean.
rm -rf /usr/share/claude-cowork-linux/.git

echo 'claude-cowork-linux staged at /usr/share/claude-cowork-linux'
