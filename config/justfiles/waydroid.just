# vim: set ft=make :
# Waydroid (Android app container) setup, adapted from Bazzite's
# 82-bazzite-waydroid.just. The bluefin-dx base doesn't ship a waydroid justfile
# under /usr/share/ublue-os/just/, and Bazzite's copy sources /usr/lib/ujust/ujust.sh,
# which this image doesn't ship — so we carry a self-contained copy that uses gum
# directly. Needs the waydroid package (recipes/recipe.yml); binder is built into
# the stock Fedora kernel.

alias configure-waydroid := setup-waydroid

# Set up Waydroid to run Android apps (init / configure / gpu / reset)
setup-waydroid ACTION="":
    #!/usr/bin/bash
    set -euo pipefail

    OPTION={{ quote(ACTION) }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-waydroid <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'init' to initialize Waydroid (downloads Android, enables the container)"
      echo "  Use 'configure' to install gapps/ARM translation/etc. via waydroid_script"
      echo "  Use 'gpu' to choose which GPU Waydroid renders on"
      echo "  Use 'reset' to wipe Waydroid and its data"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "Waydroid Setup"
      echo "Docs: https://docs.bazzite.gg/Installing_and_Managing_Software/Waydroid_Setup_Guide/"
      OPTION=$(gum choose "Initialize Waydroid" "Configure Waydroid" "Select GPU for Waydroid" "Reset Waydroid (also removes waydroid-related files from user folder)")
    fi

    if [[ "${OPTION,,}" =~ ^init ]]; then
      sudo systemctl enable --now waydroid-container
      sudo waydroid init -c 'https://ota.waydro.id/system' -v 'https://ota.waydro.id/vendor'
      echo "Waydroid has been initialized. Launch Waydroid once before running Configure Waydroid."
    elif [[ "${OPTION,,}" =~ ^configure ]]; then
      # Pin the helper to a reviewed commit. Do not execute the mutable default
      # branch as root.
      WAYDROID_SCRIPT_COMMIT=66e5d06bcb92de5d4654bef4d5c7a7c79ee4c9b3
      WORKDIR=$(mktemp -d -t myos-waydroid.XXXXXXXX)
      trap 'rm -rf "$WORKDIR"' EXIT

      git init -q "$WORKDIR/repo"
      git -C "$WORKDIR/repo" remote add origin https://github.com/ublue-os/waydroid_script.git
      git -C "$WORKDIR/repo" fetch -q --depth=1 origin "$WAYDROID_SCRIPT_COMMIT"
      git -C "$WORKDIR/repo" checkout -q --detach FETCH_HEAD

      python3 -m venv "$WORKDIR/venv"
      # Pin the helper's deps too: requirements.txt at the pinned commit is
      # unversioned (tqdm/requests/InquirerPy), so -r would install whatever
      # PyPI serves that day and then run it as root via the sudo below. Bump
      # these alongside WAYDROID_SCRIPT_COMMIT.
      "$WORKDIR/venv/bin/python" -m pip install --disable-pip-version-check \
        tqdm==4.69.0 requests==2.34.2 InquirerPy==0.3.4

      # Use the venv interpreter explicitly across sudo. Activating a venv and
      # then running `sudo pip` or a shebang script would bypass it.
      sudo "$WORKDIR/venv/bin/python" "$WORKDIR/repo/main.py"
    elif [[ "${OPTION,,}" =~ gpu ]]; then
      sudo /usr/bin/waydroid-choose-gpu
    elif [[ "${OPTION,,}" =~ ^reset ]]; then
      echo "Resetting Waydroid"
      sudo systemctl disable --now waydroid-container.service 2>/dev/null || true
      sudo rm -rf /var/lib/waydroid
      rm -rf \
        "$HOME/.waydroid" \
        "$HOME/waydroid" \
        "$HOME/.local/share/waydroid"
      find "$HOME/.local/share/applications" -maxdepth 1 -type f -iname '*aydroid*' \
        -delete 2>/dev/null || true
      echo "Waydroid has been reset"
    else
      echo "Unknown Waydroid action: $OPTION" >&2
      exit 2
    fi
