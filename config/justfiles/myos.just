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

# Show the claude-science version baked into this image vs the latest upstream
claude-science-version:
    #!/usr/bin/env bash
    set -euo pipefail
    baked="$(cat /usr/share/myos/claude-science-version 2>/dev/null || echo unknown)"
    base="https://storage.googleapis.com/operon-dist-cf94a20e-f71c-413c-bd00-9e12b1fedf59/operon-releases"
    sha8="$(curl -sf "$base/stable" || true)"
    latest="$(curl -sf "$base/${sha8}/manifest.json" 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)"
    echo "baked in image: ${baked}"
    echo "latest stable:  ${latest:-unknown (offline?)}"
    if [ -n "${latest}" ] && [ "${baked}" != "${latest}" ]; then
        echo "Update available: bump SCIENCE_SHA8/SCIENCE_VERSION/SCIENCE_SHA256 in config/scripts/getclaude-science.sh"
    fi

# Show the modal CLI version baked into this image vs the latest on PyPI
modal-version:
    #!/usr/bin/env bash
    set -euo pipefail
    baked="$(cat /usr/share/myos/modal-version 2>/dev/null || echo unknown)"
    latest="$(curl -sf https://pypi.org/pypi/modal/json | jq -r '.info.version // empty' 2>/dev/null || true)"
    echo "baked in image: ${baked}"
    echo "latest on PyPI: ${latest:-unknown (offline?)}"
    if [ -n "${latest}" ] && [ "${baked}" != "${latest}" ]; then
        echo "Update available: bump MODAL_VERSION in config/scripts/getmodal.sh"
    fi

# Show the Windscribe version baked into this image vs the latest GitHub release
windscribe-version:
    #!/usr/bin/env bash
    set -euo pipefail
    baked="$(rpm -q --queryformat '%{VERSION}' windscribe 2>/dev/null || echo unknown)"
    latest="$(curl -sf https://api.github.com/repos/Windscribe/Desktop-App/releases/latest \
        | jq -r '.tag_name // empty' 2>/dev/null | sed 's/^v//' || true)"
    echo "baked in image: ${baked}"
    echo "latest release: ${latest:-unknown (offline?)}"
    if [ -n "${latest}" ] && [ "${baked}" != "${latest}" ]; then
        echo "Update available: bump the windscribe RPM URL (v${latest}) in recipes/recipe.yml"
    fi
