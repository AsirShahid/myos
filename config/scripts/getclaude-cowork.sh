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

# Node tools the upstream launcher needs: electron + @electron/asar. Pinned with
# a full lockfile (package.json + package-lock.json under
# config/files/usr/lib/claude-cowork-deps, shipped into /usr by the files module
# before this script runs), so `npm ci` installs the exact integrity-checked
# dependency tree instead of re-resolving from the registry on every daily
# rebuild. Bump the two versions in package.json and regenerate the lock with
# `npm install --package-lock-only` deliberately; upstream's COMPAT.md tracks the
# last tested asar/electron.
#
# Installing under /usr/lib and symlinking into /usr/bin keeps the binaries on
# PATH at runtime (where /usr is read-only), so install.sh finds them and skips
# its own unpinned electron/asar install, keeping these pins load-bearing. A
# plain `npm -g` would land in /usr/local, a bootc symlink into machine-local
# /var/usrlocal, and never ship.
DEPS_DIR=/usr/lib/claude-cowork-deps
( cd "$DEPS_DIR" && npm ci --no-audit --no-fund )

# electron fetches its ~200MB binary lazily into node_modules/electron/dist;
# force that now, while /usr is writable and the network is up, so it runs
# offline at runtime.
"$DEPS_DIR/node_modules/.bin/electron" --version >/dev/null

ln -sf "$DEPS_DIR/node_modules/.bin/electron" /usr/bin/electron
ln -sf "$DEPS_DIR/node_modules/.bin/asar" /usr/bin/asar

# Fail the build if the tools aren't actually runnable, instead of shipping
# without them.
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
