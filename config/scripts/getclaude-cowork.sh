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
# Install with an explicit --prefix=/usr. Fedora's npm defaults prefix to
# /usr/local, which on a bootc image is a symlink into /var/usrlocal (machine-
# local, never shipped) — so a plain `npm -g` would silently NOT land in the
# image, and install.sh would then install whatever unpinned electron/asar the
# npm dist-tag serves that day into the user's home. --prefix=/usr puts the
# binaries in /usr/bin where they stay on PATH at runtime (read-only /usr), so
# install.sh finds them and skips its own unpinned install, keeping these pins
# load-bearing.
# Pinned so the daily image rebuild doesn't silently pull new majors; bump
# deliberately (upstream's COMPAT.md tracks the last tested asar/electron).
npm install -g --prefix=/usr @electron/asar@4.2.0 electron@42.4.0

# Fail the build if the payload didn't actually land in /usr/bin (e.g. if npm's
# prefix behavior changes), instead of silently shipping without them.
test -x /usr/bin/electron
test -x /usr/bin/asar

# Clone the upstream source read-only into the image. The launcher mirrors
# this into ~/.local/share at runtime (same strategy as the upstream Nix flake).
# Pinned to a reviewed commit so the daily image rebuild doesn't silently ship
# unvetted upstream code; bump the SHA deliberately to update.
COWORK_COMMIT=4958d953d2b58e810b56760ba9d7fcf1d0bf99a6
rm -rf /usr/share/claude-cowork-linux
git init -q /usr/share/claude-cowork-linux
git -C /usr/share/claude-cowork-linux remote add origin https://github.com/johnzfitch/claude-cowork-linux.git
git -C /usr/share/claude-cowork-linux fetch -q --depth=1 origin "$COWORK_COMMIT"
git -C /usr/share/claude-cowork-linux checkout -q FETCH_HEAD
# Drop the upstream .git to keep the image lean.
rm -rf /usr/share/claude-cowork-linux/.git

echo 'claude-cowork-linux staged at /usr/share/claude-cowork-linux'
