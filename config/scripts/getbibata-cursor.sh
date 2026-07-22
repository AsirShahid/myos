#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
set -oue pipefail

# Install the Bibata-Modern-Ice XCursor theme to /usr/share/icons.
#
# Bibata isn't packaged in any Fedora dnf repo, so pull the prebuilt XCursor
# tarball straight from the upstream GitHub release. Pinned to a specific
# version and verified against a checksum so the daily image rebuild doesn't
# silently ship whatever upstream publishes; bump the version and hash together
# deliberately. Releases:
#   https://github.com/ful1e5/Bibata_Cursor/releases
#
# The default cursor theme is set image-wide via the gschema override
# (org.gnome.desktop.interface cursor-theme); niri reads it from ~/.config/niri
# and Hyprland from ~/.config/hypr/themes/common.conf (both in the dotfiles).
BIBATA_VERSION=2.0.7
BIBATA_SHA256=a68cae60c4dc706350e194ebc91c5fe48bc7bc9d59e119555834a2a7ee5078ef

echo "Downloading Bibata-Modern-Ice ${BIBATA_VERSION}..."
curl -fL --retry 3 --retry-delay 5 --retry-all-errors -o /tmp/bibata-modern-ice.tar.xz \
  "https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VERSION}/Bibata-Modern-Ice.tar.xz"
echo "${BIBATA_SHA256}  /tmp/bibata-modern-ice.tar.xz" | sha256sum -c -

install -d /usr/share/icons
# --no-same-owner: the archive stores entries as uid/gid 1000; running as root
# tar would otherwise bake uid-1000 ownership into /usr/share/icons. Let root own
# the extracted files like the rest of /usr.
tar --no-same-owner -xf /tmp/bibata-modern-ice.tar.xz -C /usr/share/icons
rm -f /tmp/bibata-modern-ice.tar.xz

# Record the baked version so it's greppable alongside the other pins.
mkdir -p /usr/share/myos
echo "${BIBATA_VERSION}" > /usr/share/myos/bibata-cursor-version

echo 'Bibata-Modern-Ice installation completed'
