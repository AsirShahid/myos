#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
set -oue pipefail

# Install Beeper for Linux as /usr/bin/beeper.
#
# Pinned to a specific release and verified against a checksum so the daily
# image rebuild doesn't silently ship whatever upstream publishes; bump the
# version and hash together deliberately. Find the current stable version by
# following the redirect from:
#   https://api.beeper.com/desktop/download/linux/x64/stable/com.automattic.beeper.desktop
#
# Note: this is an AppImage on read-only /usr, so Beeper's built-in updater
# can't work — updates arrive through image rebuilds with a bumped pin.
BEEPER_VERSION=4.2.957
BEEPER_SHA256=c14194c16a2943ca31dbe50fe615c8205d9754b42667285f6fbd764bc2634c69

echo "Downloading Beeper ${BEEPER_VERSION}..."
curl -fL -o /tmp/beeper.AppImage \
  "https://beeper-desktop.download.beeper.com/builds/Beeper-${BEEPER_VERSION}-x86_64.AppImage"
echo "${BEEPER_SHA256}  /tmp/beeper.AppImage" | sha256sum -c -
install -m 0755 /tmp/beeper.AppImage /usr/bin/beeper
rm -f /tmp/beeper.AppImage

# Record the baked version so `ujust beeper-version` can compare with upstream.
mkdir -p /usr/share/myos
echo "${BEEPER_VERSION}" > /usr/share/myos/beeper-version

echo 'Beeper installation completed'
