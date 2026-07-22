# vim: set ft=make :
# Custom ujust recipes for myos.
#
# Shipped via the BlueBuild justfiles module, which validates these at build
# time and imports them into ujust through 60-custom.just. Don't duplicate
# recipes that already exist in the base image's just files.

# Run claude-cowork preflight diagnostics
claude-cowork-doctor:
    # Full path: after first install, install.sh writes ~/.local/bin/claude-cowork
    # earlier on PATH, and it doesn't handle these flags the way this wrapper does.
    /usr/bin/claude-cowork --doctor

# Wipe the per-user claude-cowork install and set it up again
claude-cowork-reinstall:
    /usr/bin/claude-cowork --reinstall

# Show the Beeper version baked into this image vs the latest upstream release
beeper-version:
    #!/usr/bin/env bash
    set -euo pipefail
    baked="$(cat /usr/share/myos/beeper-version 2>/dev/null || echo unknown)"
    latest="$(curl -sfI https://api.beeper.com/desktop/download/linux/x64/stable/com.automattic.beeper.desktop \
        | tr -d '\r' | sed -nE 's|^[Ll]ocation:.*/Beeper-(.+)-x86_64\.AppImage$|\1|p' || true)"
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
        echo "Update available: bump WINDSCRIBE_VERSION/WINDSCRIBE_SHA256 (v${latest}) in config/scripts/getwindscribe.sh"
    fi

alias configure-windscribe := setup-windscribe

# Guided Windscribe VPN control (login / connect with kill-switch / disconnect)
setup-windscribe ACTION="":
    #!/usr/bin/bash
    OPTION={{ quote(ACTION) }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-windscribe <option>"
      echo "  <option>: skip the menu with a quick action"
      echo "  Use 'login'      to sign in to your Windscribe account"
      echo "  Use 'connect'    to turn the kill-switch on and connect to the best server"
      echo "  Use 'disconnect' to disconnect (kill-switch stays on)"
      echo "  Use 'killswitch' to turn the firewall kill-switch on or off"
      echo "  Use 'status'     to show the current connection"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "Windscribe VPN"
      OPTION=$(gum choose "Connect (kill-switch + best server)" "Disconnect" "Log in" "Toggle kill-switch" "Status")
    fi
    # The GUI and CLI both drive this privileged daemon; make sure it's running
    # (it's enabled in the image, but may not be started yet right after install).
    if ! systemctl is-active --quiet windscribe-helper; then
      echo "Starting windscribe-helper..."
      sudo systemctl start windscribe-helper
    fi
    # windscribe-cli talks to that root helper, so the calls below need no sudo.
    if [[ "${OPTION,,}" =~ ^log ]]; then
      windscribe-cli login
    elif [[ "${OPTION,,}" =~ ^disconnect ]]; then
      windscribe-cli disconnect
      echo "Disconnected. Kill-switch is still on; run 'ujust setup-windscribe killswitch' to turn it off."
    elif [[ "${OPTION,,}" =~ connect ]]; then
      # Heuristic: Windscribe prints a 'login' hint when unauthenticated.
      if windscribe-cli status 2>&1 | grep -qiE 'login|not logged'; then
        echo "Not logged in yet."
        windscribe-cli login
      fi
      windscribe-cli firewall on   # kill-switch first, so there's no leak before the tunnel is up
      windscribe-cli connect best
      windscribe-cli status
    elif [[ "${OPTION,,}" =~ (killswitch|firewall|toggle) ]]; then
      STATE=$(gum choose "on" "off")
      windscribe-cli firewall "$STATE"
      echo "Kill-switch turned ${STATE}."
    elif [[ "${OPTION,,}" =~ ^status ]]; then
      windscribe-cli status
    else
      echo "Unknown Windscribe action: $OPTION" >&2
      echo "Run 'ujust setup-windscribe help' for the list of actions." >&2
      exit 2
    fi
