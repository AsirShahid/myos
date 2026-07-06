#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
set -oue pipefail

# Make Waydroid networking work under firewalld/nftables.
#
# Upstream waydroid-net.sh prefers `nft` and the legacy iptables binaries
# whenever it finds them, and the rules it writes that way bypass firewalld
# and leave Android apps without network/DNS. Blanking the binary detection
# forces a fallback to the plain `iptables` wrappers, which firewalld handles
# fine. This is the same sed Bazzite applies in its Containerfile.
NET_SH=/usr/lib/waydroid/data/scripts/waydroid-net.sh

if [ ! -f "${NET_SH}" ]; then
    echo "ERROR: ${NET_SH} not found — did the waydroid package layout change?" >&2
    exit 1
fi

sed -i -E 's/=.\$\(command -v (nft|ip6?tables-legacy).*/=/g' "${NET_SH}"

# Fail the build if upstream changed the script and the sed no longer applies.
if grep -qE 'command -v (nft|ip6?tables-legacy)' "${NET_SH}"; then
    echo "ERROR: waydroid-net.sh patch did not apply cleanly" >&2
    exit 1
fi

echo 'waydroid-net.sh patched to use iptables (firewalld-compatible)'
