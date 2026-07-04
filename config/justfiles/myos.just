# vim: set ft=make :
# Custom ujust recipes for myos.
#
# Shipped via the BlueBuild justfiles module, which validates these at build
# time and imports them into ujust through 60-custom.just. Don't duplicate
# recipes that already exist in the base image's just files.

# Run claude-cowork preflight diagnostics
claude-cowork-doctor:
    claude-cowork --doctor

# Wipe the per-user claude-cowork install and set it up again
claude-cowork-reinstall:
    claude-cowork --reinstall

# Show the Beeper version baked into this image vs the latest upstream release
beeper-version:
    #!/usr/bin/env bash
    set -euo pipefail
    baked="$(cat /usr/share/myos/beeper-version 2>/dev/null || echo unknown)"
    latest="$(curl -sfI https://api.beeper.com/desktop/download/linux/x64/stable/com.automattic.beeper.desktop \
        | tr -d '\r' | sed -nE 's|^[Ll]ocation:.*/Beeper-(.+)-x86_64\.AppImage$|\1|p')"
    echo "baked in image: ${baked}"
    echo "latest stable:  ${latest:-unknown (offline?)}"
    if [ -n "${latest}" ] && [ "${baked}" != "${latest}" ]; then
        echo "Update available: bump BEEPER_VERSION and BEEPER_SHA256 in config/scripts/getbeeper.sh"
    fi
