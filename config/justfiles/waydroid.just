# vim: set ft=make :
# Waydroid (Android app container) setup, copied from Bazzite's
# 82-bazzite-waydroid.just. The bluefin-dx base vendors that file under
# /usr/share/ublue-os/just/ but never imports it into ujust, and it sources
# /usr/lib/ujust/ujust.sh, which this image doesn't ship — so we carry a
# self-contained copy that uses gum directly. Needs the waydroid package
# (recipes/recipe.yml); binder is built into the stock Fedora kernel.

alias configure-waydroid := setup-waydroid

# Set up Waydroid to run Android apps (init / configure / gpu / reset)
setup-waydroid ACTION="":
    #!/usr/bin/bash
    OPTION={{ ACTION }}
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
      git clone https://github.com/ublue-os/waydroid_script.git --depth 1 /tmp/waydroid_script
      python -m venv /tmp/waydroid_script/venv
      source /tmp/waydroid_script/venv/bin/activate
      sudo pip install -r /tmp/waydroid_script/requirements.txt
      sudo /tmp/waydroid_script/main.py
      deactivate
      sudo rm -rf /tmp/waydroid_script
    elif [[ "${OPTION,,}" =~ gpu ]]; then
      sudo /usr/bin/waydroid-choose-gpu
    elif [[ "${OPTION,,}" =~ ^reset ]]; then
      echo "Resetting Waydroid"
      bash -c 'sudo rm -rf /var/lib/waydroid /home/.waydroid ~/waydroid ~/.share/waydroid ~/.local/share/applications/*aydroid* ~/.local/share/waydroid'
      echo "Waydroid has been reset"
    fi
