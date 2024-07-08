# vim: set ft=make :

# Update system, flatpaks, and containers all at once
update:
    #!/usr/bin/bash
    ublue-update --wait
    /usr/bin/topgrade --config /usr/share/ublue-os/topgrade.toml --keep

# Turn automatic updates on or off
toggle-updates ACTION="prompt":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_STATE="Disabled"
    if systemctl is-enabled ublue-update.timer | grep -q enabled; then
      CURRENT_STATE="Enabled"
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "prompt" ]; then
      echo "Automatic updates are currently: ${bold}${CURRENT_STATE}${normal}"
      echo "Enable or Disable automatic updates?"
      OPTION=$(ugum choose Enable Disable)
    elif [ "$OPTION" == "help" ]; then
      echo "Usage: ujust toggle-updates <option>"
      echo "  <option>: Specify the quick option - 'enable' or 'disable'"
      echo "  Use 'enable' to Enable automatic updates."
      echo "  Use 'disable' to Disable automatic updates."
      exit 0
    fi
    if [ "${OPTION,,}" == "enable" ]; then
      sudo systemctl enable ublue-update.timer
    elif [ "${OPTION,,}" == "disable" ]; then
      sudo systemctl disable ublue-update.timer
    fi

# Show the changelog
changelogs:
    /usr/bin/glow https://raw.githubusercontent.com/ublue-os/bazzite/main/CHANGELOG-SHORT.md --pager

# Restore the default Terminal
restore-original-terminal:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    mkdir -p $HOME/.local/share/applications
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        rm -f $HOME/.local/share/applications/org.gnome.Terminal.desktop
        cp /usr/share/applications/org.gnome.Terminal.desktop $HOME/.local/share/applications/org.gnome.Terminal.desktop
        sed -i '/NoDisplay=true/d' $HOME/.local/share/applications/org.gnome.Terminal.desktop
    else
        rm -f $HOME/.local/share/applications/org.kde.konsole.desktop
        cp /usr/share/applications/org.kde.konsole.desktop $HOME/.local/share/applications/org.kde.konsole.desktop
        sed -i '/NoDisplay=true/d' $HOME/.local/share/applications/org.kde.konsole.desktop
        echo "Done. Change your default Terminal in System Settings to complete the swap."
    fi

# Install System Flatpaks (Support for Rebasing)
_install-system-flatpaks:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        FLATPAKS="gnome_flatpaks/flatpaks"
    else
        FLATPAKS="kde_flatpaks/flatpaks"
    fi
    FLATPAK_LIST="$(curl https://raw.githubusercontent.com/ublue-os/bazzite/main/installer/${FLATPAKS} | tr '\n' ' ')"
    flatpak --system -y install --or-update ${FLATPAK_LIST}

# Install Bazzite's Steam Game Mode Startup Video
install-gamemode-video:
    mkdir -p $HOME/.local/share/Steam/config/uioverrides/movies
    rm -f $HOME/.local/share/Steam/config/uioverrides/movies/deck_startup.webm
    cp /usr/share/ublue-os/bazzite/bazzite.webm $HOME/.local/share/Steam/config/uioverrides/movies/deck_startup.webm

# Force-enable AMD pstate
pstate-force-enable:
    rpm-ostree kargs --append-if-missing=amd_pstate=active

# Configure grub bootmenu visibility and fix duplicate entries
configure-grub ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    GRUB_STATE="$(grep -P "^GRUB_TIMEOUT_STYLE=hidden" /etc/default/grub)"
    OPTION={{ ACTION }}
    if [ "$GRUB_STATE" == "GRUB_TIMEOUT_STYLE=hidden" ]; then
        GRUB_STATE="${b}Hidden${n}"
    else
        GRUB_STATE="${b}Not Hidden${n}"
    fi
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-grub <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'hide' to select Hide Grub"
      echo "  Use 'unhide' to select Unhide Grub"
      echo "  Use 'fix' to select Fix double ostree entry"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Grub menu configuration${normal}"
      echo "Grub menu is set to: $GRUB_STATE"
      OPTION=$(Choose "Hide Grub" "Unhide Grub" "Fix double ostree entry")
    fi
    if [[ "${OPTION,,}" =~ ^hide ]]; then
      sudo sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub
      echo 'GRUB_TIMEOUT_STYLE=hidden' | sudo tee -a /etc/default/grub 1>/dev/null
      echo 'GRUB_HIDDEN_TIMEOUT=1' | sudo tee -a /etc/default/grub 1>/dev/null
      if [ -d /sys/firmware/efi ]; then
        sudo grub2-mkconfig -o /etc/grub2-efi.cfg
      else
        sudo grub2-mkconfig -o /etc/grub2.cfg
      fi
    elif [[ "${OPTION,,}" =~ ^unhide ]]; then
      sudo sed -i '/GRUB_HIDDEN_TIMEOUT=1/d' /etc/default/grub
      sudo sed -i '/GRUB_TIMEOUT_STYLE=hidden/d' /etc/default/grub
      sudo sed -i 's/GRUB_TIMEOUT=0/GRUB_TIMEOUT=5/g' /etc/default/grub
      if [ -d /sys/firmware/efi ]; then
        sudo grub2-mkconfig -o /etc/grub2-efi.cfg
      else
        sudo grub2-mkconfig -o /etc/grub2.cfg
      fi
    elif [[ "${OPTION,,}" =~ ^fix ]]; then
      sudo grub2-switch-to-blscfg
      if [ -d /sys/firmware/efi ]; then
        sudo grub2-mkconfig -o /etc/grub2-efi.cfg
      else
        sudo grub2-mkconfig -o /etc/grub2.cfg
      fi
    fi

# Add user to "input" group required by certain controller drivers
add-user-to-input-group:
    #!/usr/bin/bash
    if ! grep -q "input" /etc/group; then
      sudo bash -c 'grep "input" /lib/group >> /etc/group'
    fi
    sudo usermod -a -G input $USER

# Configure watchdog (default: enabled, recovers the system in the event of a malfunction)
configure-watchdog ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    WATCHDOG_STATE="$(rpm-ostree kargs)"
    CPU_MODEL=$(lscpu --json | jq -r '."lscpu"[7]."data"')
    OPTION={{ ACTION }}
    if [[ "$WATCHDOG_STATE" =~ (nowatchdog|modprobe\.blacklist=(iTCO_wdt|sp5100_tco)) ]]; then
        WATCHDOG_STATE="${red}${b}Disabled${n}"
    else
        WATCHDOG_STATE="${green}${b}Enabled${n}"
    fi
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-watchdog <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'enable' to select Enable Watchdog"
      echo "  Use 'disable' to select Disable Watchdog"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Watchdog configuration${normal}"
      echo "Having the watchdog enabled will let it recover the system in the event of a malfunction, however"
      echo "disabling the watchdog can give a potential performance improvement due to fewer interrupts"
      echo "Watchdog is $WATCHDOG_STATE"
      OPTION=$(Choose "Enable Watchdog" "Disable Watchdog")
    fi
    if [[ "$OPTION" =~ ^enable ]]; then
      WATCHDOG_KARGS="--delete-if-present=nowatchdog"
      if [[ "$CPU_MODEL" =~ "Intel" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --delete-if-present=modprobe.blacklist=iTCO_wdt"
      elif [[ "$CPU_MODEL" =~ "AMD" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --delete-if-present=modprobe.blacklist=sp5100_tco"
      fi
      rpm-ostree kargs $WATCHDOG_KARGS
    elif [[ "$OPTION" =~ ^disable ]]; then
      WATCHDOG_KARGS="--append-if-missing=nowatchdog"
      if [[ "$CPU_MODEL" =~ "Intel" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --append-if-missing=modprobe.blacklist=iTCO_wdt"
      elif [[ "$CPU_MODEL" =~ "AMD" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --append-if-missing=modprobe.blacklist=sp5100_tco"
      fi
      rpm-ostree kargs $WATCHDOG_KARGS
    fi

# Set the default powerprofile to load when the desktop starts
configure-powerprofile ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-powerprofile <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'powersave' to select Powersave"
      echo "  Use 'balanced' to select Balanced"
      exit 0
    elif [ "$OPTION" == "" ]; then
      # Cleanup old method
      if [ -f "~/.config/autostart/bazzite-powersave.desktop" ]; then
        rm ~/.config/autostart/bazzite-powersave.desktop
      fi
      # New method from here on
      echo "${bold}Power profile configuration${normal}"
      echo "This lets you set the default power profile."
      echo "We do not recommend changing this from ${b}Balanced${n} if you use this device primarily for gaming!"
      echo "If you have any performance or audio related issues..."
      echo "${invert}${b}Please test with the default power profile set to Balanced${n} before reporting!"
      echo ""
      echo "Which power profile do you want to use when the desktop loads?"
      OPTION=$(Choose "Powersave" "Balanced")
    fi
    if [[ "${OPTION,,}" =~ powersave ]]; then
      echo "Setting default powerprofile to ${b}Powersave${n}"
      sudo sed -iE 's/default=(.+)/default=power-saver/' /etc/tuned/ppd.conf
      /usr/libexec/bazzite-powersave
    elif [[ "${OPTION,,}" =~ balanced ]]; then
      echo "Setting default powerprofile to ${b}Balanced${n}"
      sudo sed -iE 's/default=(.+)/default=balanced/' /etc/tuned/ppd.conf
      /usr/libexec/bazzite-powersave 0
    fi

# Install and configure Decky Loader (https://github.com/SteamDeckHomebrew/decky-loader) and plugins for alternative handhelds
setup-decky ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    DECKY_STATE="${b}${red}Not Installed${n}"
    if [[ -d $HOME/homebrew/plugins ]]; then
      DECKY_STATE="${b}${green}Installed${n}"
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-watchdog <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'install' to select Install Decky"
      echo "  Use 'simpledeckytdp' to select Get SimpleDeckyTDP"
      echo "  Use 'hhd-decky' to select Get HHD-decky"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Setup Decky Loader${normal}"
      echo "This lets you setup decky and install some decky plugins for alternative handhelds"
      echo "Tip: CTRL+Click on the plugin name to visit the project page for more info"
      echo "Decky Loader is $DECKY_STATE"
      OPTION=$(
        Choose \
        "Install Decky" \
        "Get $(Urllink "https://github.com/aarron-lee/SimpleDeckyTDP" SimpleDeckyTDP)${n}" \
        "Get $(Urllink "https://github.com/hhd-dev/hhd-decky" HHD-Decky)${n}"
        )
    fi
    if [[ "${OPTION,,}" =~ install ]]; then
      export HOME=$(getent passwd ${SUDO_USER:-$USER} | cut -d: -f6)
      curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh
      sudo chcon -R -t bin_t $HOME/homebrew/services/PluginLoader
    elif [[ "${OPTION,,}" =~ simpledeckytdp ]]; then
      if [[ -d $HOME/homebrew/plugins ]]; then
        sudo rm -rf $HOME/homebrew/plugins/SimpleDeckyTDP
        curl -L $(curl -s https://api.github.com/repos/aarron-lee/SimpleDeckyTDP/releases/latest | grep "browser_download_url" | cut -d '"' -f 4) -o /tmp/SimpleDeckyTDP.tar.gz
        sudo tar -xzf /tmp/SimpleDeckyTDP.tar.gz -C $HOME/homebrew/plugins
        rm /tmp/SimpleDeckyTDP.tar.gz
        sudo sed -i 's/ENABLE_HARDWARE_CONTROL_ON_NON_DECK_HARDWARE=0/ENABLE_HARDWARE_CONTROL_ON_NON_DECK_HARDWARE=1/g' /etc/default/steam-hardware-control
        echo 'Installed. Please reboot to apply needed changes.'
      else
        echo 'Please install Decky Loader by running "ujust setup-decky install" first.'
      fi
    elif [[ "${OPTION,,}" =~ hhd-decky ]]; then
      if [[ -d $HOME/homebrew/plugins ]]; then
        sudo rm -rf $HOME/homebrew/plugins/hhd-decky
        curl -L $(curl -s https://api.github.com/repos/hhd-dev/hhd-decky/releases/latest | grep "browser_download_url" | cut -d '"' -f 4) -o /tmp/hhd-decky.tar.gz
        sudo tar -xzf /tmp/hhd-decky.tar.gz -C $HOME/homebrew/plugins
        rm /tmp/hhd-decky.tar.gz
        echo 'Installed.'
      else
        echo 'Please install Decky Loader by running "ujust setup-decky install" first.'
      fi
    fi

# Install EmuDeck (https://www.emudeck.com/)
install-emudeck:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    echo 'Retrieving EmuDeck...'
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
      wget https://www.emudeck.com/EmuDeck.desktop -O ~/.local/share/applications/EmuDeck.desktop
      echo 'EmuDeck installer added to your application grid.'
    else
      wget https://www.emudeck.com/EmuDeck.desktop -O ~/Desktop/EmuDeck.desktop
      echo 'EmuDeck installer added to your desktop.'
    fi

# Ptyxis terminal transparency
ptyxis-transparency opacity="0.95":
    #!/usr/bin/bash
    set -euxo pipefail
    if [[ -n "$(echo "{{ opacity }}" | grep -v '^[.0-9]*$')" ]]; then
      printf "Value must be numeric: %s.\n" "{{ opacity }}"
    elif [[ $(echo "0<{{ opacity }} && 1>={{ opacity }}" | bc -q) -eq 1 ]]; then
      raw="$(gsettings get org.gnome.Ptyxis profile-uuids)"
      uuids="$(sed -En 's|[^0-9a-z]*||g; s|([0-9a-z]{32})|\1\n|gp' <<<${raw})"
      for i in ${uuids}; do
        location="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${i}/"
        gsettings set "${location}" opacity "{{ opacity }}"; done
      printf "Ptyxis opacity is now %s.\n" "{{ opacity }}"
    else
      printf "Value must be between 0 and 1: %s.\n" "{{ opacity }}"
    fi

# Fix the default Steam config to improve download speeds
fix-steam-download-speed:
    mkdir -p $HOME/.local/share/Steam
    rm -f $HOME/.local/share/Steam/steam_dev.cfg
    bash -c 'printf "@nClientDownloadEnableHTTP2PlatformLinux 0\n@fDownloadRateImprovementToAddAnotherConnection 1.0\n" > $HOME/.local/share/Steam/steam_dev.cfg'

# Patch GMod's 64-bit beta to work properly on Linux (https://github.com/solsticegamestudios/GModCEFCodecFix)
fix-gmod:
    #!/usr/bin/bash
    mkdir -p /tmp/patch-gmod
    wget \
      $(curl -s https://api.github.com/repos/solsticegamestudios/GModCEFCodecFix/releases/latest | \
      jq -r ".assets[] | select(.name | test(\"GModCEFCodecFix-Linux\")) | .browser_download_url") \
      -P /tmp/patch-gmod
    chmod +x /tmp/patch-gmod/GModCEFCodecFix-Linux
    /tmp/patch-gmod/GModCEFCodecFix-Linux
    rm -rf /tmp/patch-gmod

# Kills all processes related to wine and proton. This forces it to restart next time you launch the game (you might still have to press STOP in steam to kill the game binary)
fix-proton-hang:
    #!/usr/bin/bash
    PROTONCORE=(pv-bwrap pressure-vessel reaper explorer.exe rpcss.exe plugplay.exe services.exe svchost.exe winedevice.exe winedevice.exe wineserver)
    for PROG in "${PROTONCORE[@]}"; do
      killall -9 "$PROG"
    done

# Install LACT for overclocking & undervolting AMD GPUs
install-lact:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    ublue-update --wait
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        echo 'Installing LACT Libadwaita...'
        wget \
          $(curl -s https://api.github.com/repos/ilya-zlobintsev/LACT/releases/latest | \
          jq -r ".assets[] | select(.name | test(\"lact-libadwaita.*fedora-$(rpm -E %fedora)\")) | .browser_download_url") \
          -O /tmp/lact.rpm
    else
        echo 'Installing LACT...'
        wget \
          $(curl -s https://api.github.com/repos/ilya-zlobintsev/LACT/releases/latest | \
          jq -r ".assets[] | select(.name | test(\"lact-[0-9].*fedora-$(rpm -E %fedora)\")) | .browser_download_url") \
          -O /tmp/lact.rpm
    fi
    rpm-ostree install --apply-live -y /tmp/lact.rpm
    sudo systemctl enable --now lactd
    rm /tmp/lact.rpm
    echo 'Complete.'

# Install CoolerControl, a GUI for viewing all your system's sensors and for creating custom fan and pump profiles based on any available temperature sensor28
install-coolercontrol:
    #!/usr/bin/bash
    ublue-update --wait
    sudo wget https://copr.fedorainfracloud.org/coprs/codifryed/CoolerControl/repo/fedora-$(rpm -E %fedora)/codifryed-CoolerControl-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_codifryed-CoolerControl.repo
    rpm-ostree install --apply-live -y liquidctl coolercontrol
    systemctl enable coolercontrold.service
    mkdir -p $HOME/.config/autostart
    cp /usr/share/applications/org.coolercontrol.CoolerControl.desktop $HOME/.config/autostart/org.coolercontrol.CoolerControl.desktop
    echo 'Complete.'


# Install SteamCMD (https://developer.valvesoftware.com/wiki/SteamCMD)
install-steamcmd:
    echo 'Installing SteamCMD...'
    wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz -O /tmp/steamcmd.tar.gz
    mkdir -p ~/.steam
    tar -xvzf /tmp/steamcmd.tar.gz -C ~/.steam
    rm /tmp/steamcmd.tar.gz

# Install OpenRazer for Razer gaming hardware
install-openrazer:
    sudo wget https://download.opensuse.org/repositories/hardware:/razer/Fedora_$(rpm -E %fedora)/hardware:razer.repo -O /etc/yum.repos.d/hardware:razer.repo && \
    ublue-update --wait && \
    rpm-ostree install -y openrazer-meta razergenie && \
    if ! grep -q "plugdev" /etc/group; then \
      sudo bash -c 'grep "plugdev" /lib/group >> /etc/group' \
    ; fi && \
    sudo usermod -a -G plugdev $USER && \
    echo "Please reboot to apply needed changes."

# Install Wootility for configuring Wooting Keyboards
install-wootility:
    #!/usr/bin/bash
    if grep -q 'it.mijorus.gearlever' <<< $(flatpak list); then
      wget "https://api.wooting.io/public/wootility/download?os=linux&branch=lekker" -O $HOME/Downloads/wootility.AppImage
      flatpak run it.mijorus.gearlever $HOME/Downloads/wootility.AppImage
    else
      wget "https://api.wooting.io/public/wootility/download?os=linux&branch=lekker" -O $HOME/Desktop/wootility.AppImage
      chmod +x $HOME/Desktop/wootility.AppImage
    fi

# Install Adwaita-for-Steam theme for CSS Loader (https://github.com/tkashkin/Adwaita-for-Steam)
install-adwaita-for-steam:
    #!/usr/bin/bash
    if [ -d "$HOME/homebrew/themes" ]; then
        rm -rf "$HOME/homebrew/themes/Adwaita-for-Steam"
        git clone https://github.com/tkashkin/Adwaita-for-Steam.git --single-branch "$HOME/homebrew/themes/Adwaita-for-Steam"
    else
        echo 'Please install Decky Loader by running "ujust setup-decky install" first, then install CSS Loader from the Decky Plugin Store.'
    fi

# Install Oversteer for Logitech steering wheels
install-oversteer: distrobox-check-fedora
    distrobox enter -n fedora -- bash -c 'sudo dnf copr enable -y kylegospo/oversteer && \
      sudo dnf install -y oversteer && \
      distrobox-export --app oversteer'

# Install Resilio Sync, a file synchronization utility powered by BitTorrent
install-resilio-sync: distrobox-check-fedora
    distrobox-enter -n fedora -- bash -c 'sudo rpm --import https://linux-packages.resilio.com/resilio-sync/key.asc' && \
    distrobox-enter -n fedora -- bash -c 'sudo wget https://raw.githubusercontent.com/ublue-os/bazzite/main/post_install_files/resilio_sync/resilio-sync.repo -O /etc/yum.repos.d/resilio-sync.repo' && \
    distrobox-enter -n fedora -- bash -c 'sudo dnf install -y resilio-sync' && \
    mkdir -p ~/.config/systemd/user/ && \
    rm -f ~/.config/systemd/user/fedora-resilio-sync.service && \
    wget https://raw.githubusercontent.com/ublue-os/bazzite/main/post_install_files/resilio_sync/fedora-resilio-sync.service -O ~/.config/systemd/user/fedora-resilio-sync.service && \
    systemctl --user daemon-reload && \
    systemctl enable --user --now fedora-resilio-sync.service

# Install scrcpy, a utility that mirrors Android devices (video and audio) connected via USB or over TCP/IP
install-scrcpy: distrobox-check-fedora
    distrobox enter -n fedora -- bash -c 'sudo dnf copr enable -y zeno/scrcpy && \
      sudo dnf install -y scrcpy && \
      distrobox-export --app scrcpy'

# Install OpenTabletDriver, an open source, cross-platform, user-mode tablet driver
install-opentabletdriver:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    if grep -qvz "arch" <<< $(distrobox list); then \
      Assemble noconfirmcreate "" "arch"; \
    fi && \
    distrobox enter -n arch -- bash -c 'paru -S opentabletdriver --noconfirm' && \
    mkdir -p ~/.config/systemd/user/ && \
    rm -f ~/.config/systemd/user/arch-opentabletdriver.service && \
    wget https://raw.githubusercontent.com/ublue-os/bazzite/main/post_install_files/OpenTabletDriver/opentabletdriver.service -O ~/.config/systemd/user/arch-opentabletdriver.service && \
    systemctl --user daemon-reload && \
    systemctl enable --user --now arch-opentabletdriver.service && \
    distrobox enter -n arch -- bash -c 'distrobox-export --app otd-gui'

# Create fedora distrobox if it doesn't exist
[private]
distrobox-check-fedora:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    if grep -qvz "fedora" <<< $(distrobox list); then
      echo "Setting up Fedora distrobox"
      Assemble noconfirmcreate "" "fedora"
    fi

# Setup and configure CDEmu Daemon and Client plus GUI Apps
setup-cdemu ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    CDEMU_STATE="$(rpm -qa cdemu-daemon)"
    GUI_EDITION="$(cat /etc/os-release | grep VARIANT_ID | sed 's/^.*=//')"
    OPTION={{ ACTION }}
    if [ "$CDEMU_STATE" == "" ]; then
        CDEMU_STATE="${red}${b}Not Installed${n}"
    else
        CDEMU_STATE="${green}${b}Installed${n}"
    fi
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-cdemu <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'install' to select Install CDEmu"
      echo "  Use 'remove' to select Remove CDEmu"
      echo "  Use 'remove-gui-helper' if you don't want to have the GUI"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}CDEmu setup and configuration${normal}"
      echo "CDEmu is $CDEMU_STATE"
      OPTION=$(Choose "Install CDEmu" "Remove CDEmu" "Remove GUI Helper")
    fi
    if [[ "${OPTION,,}" =~ ^install ]]; then
      if [[ "$CDEMU_STATE" != "" ]]; then
        echo "${red} CDEmu has already been installed!"
        exit 0
      fi
      ublue-update --wait
      if [[ "$GUI_EDITION" == "kinoite" ]]; then
            # Install packages for KDE 6
            rpm-ostree install --apply-live -y cdemu-daemon cdemu-client kde-cdemu-manager-kf6
      else
            # Install packages for GNOME
            rpm-ostree install --apply-live -y cdemu-daemon cdemu-client gcdemu
      fi
      # Kickstart the service manually on first install, it doesn't seem to be doing that by default.
      systemctl start --user cdemu-daemon.service
      echo "CDEmu is installed!"
    elif [[ "${OPTION,,}" =~ ^(remove|uninstall) ]]; then
      if [[ "$CDEMU_STATE" == "" ]]; then
        echo "${red} CDEmu has already been removed!"
        exit 0
      fi
      ublue-update --wait
      if [[ "$GUI_EDITION" == "kinoite" ]]; then
        # Remove packages for KDE 6
        GUI_STATE="$(rpm -qa kde-cdemu-manager-kf6)"
        #GUI already removed
        if [[GUI_STATE == ""]]; then
          rpm-ostree remove -y cdemu-daemon cdemu-client
        else
          rpm-ostree remove -y cdemu-daemon cdemu-client kde-cdemu-manager-kf6
        fi
      else
        # Remove packages for GNOME
        GUI_STATE="$(rpm -qa gcdemu)"
        #GUI already removed
        if [["${GUI_STATE,,}" == ""]]; then
          rpm-ostree remove -y cdemu-daemon cdemu-client
        else
          rpm-ostree remove -y cdemu-daemon cdemu-client gcdemu
        fi
      fi
      echo "CDEmu has been uninstalled."
    elif [[ "${OPTION,,}" =~ helper ]]; then
      if [[ "$GUI_EDITION" == "kinoite" ]]; then
        GUI_STATE="$(rpm -qa kde-cdemu-manager-kf6)"
        if [["$GUI_STATE" == ""]]; then
          echo "GUI has already been removed or the package is not yet installed!"
        else
          rpm-ostree remove -y kde-cdemu-manager-kf6
          echo "GUI has been removed, you can still mount images using the CLI with the cdemu command."
        fi
      else
        GUI_STATE="$(rpm -qa gcdemu)"
        if [["$GUI_STATE" == ""]]; then
          echo "GUI has already been removed or the package is not yet installed!"
        else
          rpm-ostree remove -y gcdemu
          echo "GUI has been removed, you can still mount images using the CLI with the cdemu command."
        fi
      fi
    fi

# Reenable rmlint trim feature
enable-rmlint ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    OPTION={{ ACTION }}
    if [[ ! -f "/etc/systemd/system/btrfs-dedup@.service.d/override.conf" ]]; then
        RMLINT_STATE="${red}${b}not enabled{n}"
    else
        RMLINT_STATE="${green}${b}already enabled${n}"
    fi
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust enable-rmlint <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'enable' to reenable rmlint functionality"
      echo "  Use 'disable' to revert to UBlue stock configuration (only duperemove is executed)"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}rmlint configuration${normal}"
      echo "rmlint conf is $RMLINT_STATE"
      OPTION=$(Choose "Enable rmlint" "Disable rmlint")
    fi
    if [[ "${OPTION,,}" =~ ^enable ]]; then
      if [[ "${RMLINT_STATE,,}" =~ "^already" ]]; then
        echo "${red} rmlint has already been enabled!"
        exit 0
      fi
      ublue-update --wait
      rpm-ostree install --apply-live -y rmlint
      mkdir /etc/systemd/system/btrfs-dedup@.service.d/
      bash -c 'cat << EOL > /etc/systemd/system/btrfs-dedup@.service.d/override.conf
      [Unit]
      Description=Btrfs deduplication on %f
      ConditionPathIsMountPoint=%f
      RequiresMountsFor=%f

      [Service]
      Type=oneshot
      MemoryHigh=1G
      ExecCondition=sh -c '[ "$(stat -f -c "%%T" "$1")" = btrfs ]' _ %f/
      ExecStartPre=-find %f/ -mindepth 1 -maxdepth 1 -mtime +14 -name .duperemove.hash -exec rm -f '{}' \;
      ExecStartPre=-cp -a %f/.duperemove.hash duperemove.hash
      ExecStartPre=-compsize %f/
      ExecStart=rmlint --hidden --types="duplicates" --config=sh:handler=clone %f/
      ExecStart=sh -c 'exec ./rmlint.sh -d -p -r -k'
      ExecStart=-compsize %f/
      ExecStart=-sh -c '[ "$(sqlite3 -readonly duperemove.hash "SELECT keyval FROM config where keyname=''version_major''")" -ge 4 ] || rm -f duperemove.hash'
      ExecStart=duperemove -r -d -h -q --hashfile=duperemove.hash --skip-zeroes --exclude="%f/.duperemove.hash" --exclude="%f/@swapfile/swapfile" %f/
      ExecStartPost=-compsize %f/
      ExecStopPost=-cp -a duperemove.hash %f/.duperemove.hash
      TimeoutStartSec=4h
      RuntimeDirectory=%p/%i
      WorkingDirectory=%t/%p/%i
      Nice=19
      CPUSchedulingPolicy=batch
      IOSchedulingClass=best-effort
      IOSchedulingPriority=7
      OOMScoreAdjust=1000
      CPUWeight=30
      CPUQuota=300%
      IOWeight=30
    EOL'
      echo "rmlint has been reenabled!"
    elif [[ "${OPTION,,}" =~ ^(disable|uninstall) ]]; then
      if [[ "${RMLINT_STATE,,}" =~ "^not" ]]; then
        echo "${red} rmlint has already been disabled!"
        exit 0
      fi
      ublue-update --wait
      rpm-ostree remove -y rmlint
      rm /etc/systemd/system/btrfs-dedup@.service.d/override.conf
      rmdir /etc/systemd/system/btrfs-dedup@.service.d/
      echo "rmlint has been disabled."
    fi

# Setup and configure Sunshine Game Streaming host
setup-sunshine ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    SUNSHINE_STATE="$(rpm -qa sunshine)"
    SERVICE_STATE="$(systemctl is-enabled --user sunshine.service)"
    OPTION={{ ACTION }}
    if [ "$SUNSHINE_STATE" == "" ]; then
        SUNSHINE_STATE="${red}${b}Not Installed${n}"
    else
        SUNSHINE_STATE="${green}${b}Installed${n}"
    fi
    if [ "$SERVICE_STATE" == "enabled" ]; then
        SERVICE_STATE="${green}${b}Enabled${n}"
    else
        SERVICE_STATE="${red}${b}Disabled${n}"
    fi
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-sunshine <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'install' to select Install Sunshine"
      echo "  Use 'remove' to select Remove Sunshine"
      echo "  Use 'autostart' to select Toggle Autostart"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Sunshine setup and configuration${normal}"
      echo "Sunshine is $SUNSHINE_STATE"
      echo "Service is $SERVICE_STATE"
      OPTION=$(Choose "Install Sunshine" "Remove Sunshine" "Toggle Autostart")
    fi
    if [[ "${OPTION,,}" =~ ^install ]]; then
      systemctl enable sunshine-workaround.service
      ublue-update --wait
      rpm-ostree install --apply-live -y sunshine
      echo "Sunshine is installed!"
    elif [[ "${OPTION,,}" =~ ^(remove|uninstall) ]]; then
      systemctl disable sunshine-workaround.service
      ublue-update --wait
      rpm-ostree remove -y sunshine
      echo "Sunshine has been uninstalled."
    elif [[ "${OPTION,,}" =~ autostart ]]; then
      if [[ "${SERVICE_STATE,,}" =~ disabled ]]; then
        systemctl enable --user --now sunshine.service
      else
        systemctl disable --user --now sunshine.service 
      fi
    fi

# Launch Waydroid configuration helper
setup-waydroid ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    IMAGE_NAME=$(jq -r '."image-name"' < $IMAGE_INFO)
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-waydroid <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'init' to select Initialize Waydroid"
      echo "  Use 'configure' to select Configure Waydroid"
      echo "  Use 'gpu' to choose Select GPU for Waydroid"
      echo "  Use 'reset' to select Configure Waydroid"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Waydroid Setup${normal}"
      echo "Please read the $(Urllink "https://universal-blue.discourse.group/docs?topic=32" "Waydroid setup documentation") before continuing"
      OPTION=$(Choose "Initialize Waydroid" "Configure Waydroid" "Select GPU for Waydroid" "Reset Waydroid (also removes waydroid-related files from user folder)")
    fi
    if [[ "${OPTION,,}" =~ ^init ]]; then
      if [[ ! $IMAGE_NAME =~ "deck" && ! $IMAGE_NAME =~ "ally" && ! $IMAGE_NAME =~ "framegame" ]]; then
        sudo systemctl enable --now waydroid-container
      fi
      sudo waydroid init -c 'https://ota.waydro.id/system' -v 'https://ota.waydro.id/vendor'
      echo "Waydroid has been initialized, please run waydroid once before you Configure Waydroid"
    elif [[ "${OPTION,,}" =~ ^configure ]]; then
      git clone https://github.com/ublue-os/waydroid_script.git --depth 1 /tmp/waydroid_script
      python -m venv /tmp/waydroid_script/venv
      source /tmp/waydroid_script/venv/bin/activate
      sudo pip install -r /tmp/waydroid_script/requirements.txt
      sudo /tmp/waydroid_script/main.py
      deactivate
      sudo rm -rf /tmp/waydroid_script
    elif [[ "${OPTION,,}" =~ gpu ]]; then
      /usr/bin/waydroid-choose-gpu
    elif [[ "${OPTION,,}" =~ ^reset ]]; then
      echo "Resetting Waydroid"
      bash -c 'sudo rm -rf /var/lib/waydroid /home/.waydroid ~/waydroid ~/.share/waydroid ~/.local/share/applications/*aydroid* ~/.local/share/waydroid'
      echo "Waydroid has been reset"
    fi

# Add virtual audio channels/sinks named Game, Voice, Browser and Music which you can split audio to using qpwgraph, helvum, carla or other pipewire patchbays for use in OBS and other use cases
setup-virtual-channels ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    IMAGE_NAME=$(jq -r '."image-name"' < $IMAGE_INFO)
    # Set default props, for deck images make sure default output is valves virtual-sink
    PROPS='node.name      = "playback.game_output"
                    audio.position = [ FL FR ]
                    node.passive   = true'
    if [[ "$IMAGE_NAME" =~ deck ]]; then
        PROPS='node.name      = "playback.game_output"
                    audio.position = [ FL FR ]
                    node.passive   = true
                    target.object = "input.virtual-sink"'
    fi
    mkdir -p ~/.config/pipewire/pipewire.conf.d
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-virtual-channels <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'create' to select Create Virtual Audio Channels"
      echo "  Use 'remove' to select Remove Virtual Audio Channels"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Virtual Audio Channels configuration${normal}"
      OPTION=$(Choose "Create Virtual Audio Channels" "Remove Virtual Audio Channels")
    fi
    if [[ "${OPTION,,}" =~ ^create ]]; then
      PLAYBACK_PROPS=$PROPS bash -c 'cat << EOL > ~/.config/pipewire/pipewire.conf.d/virtual-channels.conf
    context.modules = [
        { name = libpipewire-module-loopback
            args = {
                node.description = "Game"
                capture.props = {
                    node.name      = "game_output"
                    media.class    = "Audio/Sink"
                    audio.position = [ FL FR ]
                }
                playback.props = {
                    $PLAYBACK_PROPS
                }
            }
        }
        { name = libpipewire-module-loopback
            args = {
                node.description = "Voice"
                capture.props = {
                    node.name      = "voice_output"
                    media.class    = "Audio/Sink"
                    audio.position = [ FL FR ]
                }
                playback.props = {
                    $PLAYBACK_PROPS
                }
            }
        }
        { name = libpipewire-module-loopback
            args = {
                node.description = "Browser"
                capture.props = {
                    node.name      = "browser_output"
                    media.class    = "Audio/Sink"
                    audio.position = [ FL FR ]
                }
                playback.props = {
                    $PLAYBACK_PROPS
                }
            }
        }
        { name = libpipewire-module-loopback
            args = {
                node.description = "Music"
                capture.props = {
                    node.name      = "music_output"
                    media.class    = "Audio/Sink"
                    audio.position = [ FL FR ]
                }
                playback.props = {
                    $PLAYBACK_PROPS
                }
            }
        }
    ]
    EOL'
      echo "Next time you log in, you will have audio channels for Game, Voice, Browser, Music that you can route game audio to"
      echo "using programs like Pulseaudio volume control, coppwr, qpwgraph, helvum or carla."
      echo "You can also add these channels to OBS audio mixer for separate audio control for yourself and your viewers."
      echo "NOTE: It is recommended to mute the virtual channels so you do not have to listen to them twice if you are not exclusively routing the audio through said channel instead of splitting audio to them."
    elif [[ "${OPTION,,}" =~ ^remove ]]; then
      rm ~/.config/pipewire/pipewire.conf.d/virtual-channels.conf
      echo "Virtual audio channels config removed, the channels will be removed next time you login."
    fi

# Setup a simple Virtual Surround 7.1 sink using the ASH Control Room 1 convolver file (you can change this yourself after setup)
setup-virtual-surround ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    mkdir -p ~/.config/pipewire/pipewire.conf.d
    mkdir -p ~/.config/pipewire/hrir_hesuvi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-virtual-surround <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'enable' to select Enable Virtual Surround"
      echo "  Use 'disable' to select Disable Virtual Surround"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Virtual Surround configuration${normal}"
      OPTION=$(Choose "Enable Virtual Surround" "Disable Virtual Surround")
    fi
    if [[ "${OPTION,,}" =~ ^enable ]]; then
      echo "Downloading HeSuVi convolver profile Control Room 1 from https://github.com/ShanonPearce/ASH-Listening-Set"
      wget -O ~/.config/pipewire/hrir_hesuvi/Control_Room_1.wav https://github.com/ShanonPearce/ASH-Listening-Set/raw/main/HeSuVi/hrir/_Control_Room_1.wav
      bash -c 'cat << HESUVI > ~/.config/pipewire/pipewire.conf.d/virtual-surround-71.conf
    context.modules = [
       { name = libpipewire-module-filter-chain
           flags = [ nofail ]
           args = {
               node.description = "Virtual Surround 7.1"
               media.name       = "Virtual Surround 7.1"
               filter.graph = {
                   nodes = [
                       # Duplicate inputs
                       { type = builtin label = copy name = copyFL  }
                       { type = builtin label = copy name = copyFR  }
                       { type = builtin label = copy name = copyFC  }
                       { type = builtin label = copy name = copyRL  }
                       { type = builtin label = copy name = copyRR  }
                       { type = builtin label = copy name = copySL  }
                       { type = builtin label = copy name = copySR  }
                       { type = builtin label = copy name = copyLFE }

                       # Apply hrir - HeSuVi 14-channel WAV (not the *-.wav variants) (note: */44/* in HeSuVi are the same, but resampled to 44100)
                       # The file paths HAS to be absolute paths
                       { type = builtin label = convolver name = convFL_L config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  0 } }
                       { type = builtin label = convolver name = convFL_R config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  1 } }
                       { type = builtin label = convolver name = convSL_L config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  2 } }
                       { type = builtin label = convolver name = convSL_R config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  3 } }
                       { type = builtin label = convolver name = convRL_L config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  4 } }
                       { type = builtin label = convolver name = convRL_R config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  5 } }
                       { type = builtin label = convolver name = convFC_L config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  6 } }
                       { type = builtin label = convolver name = convFR_R config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  7 } }
                       { type = builtin label = convolver name = convFR_L config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  8 } }
                       { type = builtin label = convolver name = convSR_R config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  9 } }
                       { type = builtin label = convolver name = convSR_L config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel = 10 } }
                       { type = builtin label = convolver name = convRR_R config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel = 11 } }
                       { type = builtin label = convolver name = convRR_L config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel = 12 } }
                       { type = builtin label = convolver name = convFC_R config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel = 13 } }

                       # Treat LFE as FC
                       { type = builtin label = convolver name = convLFE_L config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel =  6 } }
                       { type = builtin label = convolver name = convLFE_R config = { filename = "$HOME/.config/pipewire/hrir_hesuvi/Control_Room_1.wav" channel = 13 } }

                       # Stereo output
                       { type = builtin label = mixer name = mixL }
                       { type = builtin label = mixer name = mixR }
                   ]
                   links = [
                       # Input
                       { output = "copyFL:Out"  input="convFL_L:In"  }
                       { output = "copyFL:Out"  input="convFL_R:In"  }
                       { output = "copySL:Out"  input="convSL_L:In"  }
                       { output = "copySL:Out"  input="convSL_R:In"  }
                       { output = "copyRL:Out"  input="convRL_L:In"  }
                       { output = "copyRL:Out"  input="convRL_R:In"  }
                       { output = "copyFC:Out"  input="convFC_L:In"  }
                       { output = "copyFR:Out"  input="convFR_R:In"  }
                       { output = "copyFR:Out"  input="convFR_L:In"  }
                       { output = "copySR:Out"  input="convSR_R:In"  }
                       { output = "copySR:Out"  input="convSR_L:In"  }
                       { output = "copyRR:Out"  input="convRR_R:In"  }
                       { output = "copyRR:Out"  input="convRR_L:In"  }
                       { output = "copyFC:Out"  input="convFC_R:In"  }
                       { output = "copyLFE:Out" input="convLFE_L:In" }
                       { output = "copyLFE:Out" input="convLFE_R:In" }

                       # Output
                       { output = "convFL_L:Out"  input="mixL:In 1" }
                       { output = "convFL_R:Out"  input="mixR:In 1" }
                       { output = "convSL_L:Out"  input="mixL:In 2" }
                       { output = "convSL_R:Out"  input="mixR:In 2" }
                       { output = "convRL_L:Out"  input="mixL:In 3" }
                       { output = "convRL_R:Out"  input="mixR:In 3" }
                       { output = "convFC_L:Out"  input="mixL:In 4" }
                       { output = "convFC_R:Out"  input="mixR:In 4" }
                       { output = "convFR_R:Out"  input="mixR:In 5" }
                       { output = "convFR_L:Out"  input="mixL:In 5" }
                       { output = "convSR_R:Out"  input="mixR:In 6" }
                       { output = "convSR_L:Out"  input="mixL:In 6" }
                       { output = "convRR_R:Out"  input="mixR:In 7" }
                       { output = "convRR_L:Out"  input="mixL:In 7" }
                       { output = "convLFE_R:Out" input="mixR:In 8" }
                       { output = "convLFE_L:Out" input="mixL:In 8" }
                   ]
                   inputs  = [ "copyFL:In" "copyFR:In" "copyFC:In" "copyLFE:In" "copyRL:In" "copyRR:In", "copySL:In", "copySR:In" ]
                   outputs = [ "mixL:Out" "mixR:Out" ]
               }
               capture.props = {
                   node.name      = "effect_input.virtual-surround-7.1-hesuvi"
                   media.class    = Audio/Sink
                   audio.channels = 8
                   audio.position = [ FL FR FC LFE RL RR SL SR ]
               }
               playback.props = {
                   node.name      = "effect_output.virtual-surround-7.1-hesuvi"
                   node.passive   = true
                   audio.channels = 2
                   audio.position = [ FL FR ]
               }
           }
       }
    ]
    HESUVI'
      echo "Virtual Surround 7.1 has now been set up with a basic convolver file, either restart pipewire or reboot for it to take effect."
      echo "Then select the Virtual Surround 7.1 audio output as your default audio output."
      echo "If you want something like DTS, Atmos or OpenAL, you will have to acquire those convolver wav files yourself and edit ~/.config/pipewire/pipewire.conf.d/virtual-surround-71.conf to point to the one you want to use."
    elif [[ "${OPTION,,}" =~ ^disable ]]; then
      rm ~/.config/pipewire/pipewire.conf.d/virtual-surround-71.conf
      rm ~/.config/pipewire/hrir_hesuvi/Control_Room_1.wav
      echo "Virtual Surround 7.1 removed, please reboot or restart pipewire for it to take effect." 
    fi

# Restart pipewire
restart-pipewire:
    echo "Restarting pipewire..."
    systemctl --user restart pipewire.service

# Setup and configure virtualization and vfio
setup-virtualization ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    # Check if we are running on a Steam Deck
    if /usr/libexec/hwsupport/valve-hardware; then
      echo "${red}${b}WARNING${n}: Virtualization is not properly supported on Steam Deck by Valve"
      echo "Use at your own risk and performance may not be ideal."
    fi
    if [ "$(systemctl is-enabled libvirtd.service)" == "disabled" ]; then
      echo "${b}libvirtd${n} service is ${red}disabled${n}!"
      echo "${green}enabling${n} and starting libvirtd"
      echo "If virt-manager says libvirtd.sock is not available after a big update, re-run this command."
      sudo systemctl enable --now libvirtd 2> /dev/null
      echo "Press ESC if you want to exit and do not need to do anything"
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-virtualization <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'virt-on' to select Enable Virtualization"
      echo "  Use 'virt-off' to select Disable Virtualization"
      echo "  Use 'group' to select Add $USER to libvirt group"
      echo "  Use 'vfio-on' to select Enable VFIO drivers"
      echo "  Use 'vfio-off' to select Disable VFIO drivers"
      echo "  Use 'kvmfr' to select Autocreate Looking-Glass shm"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Virtualization Setup${normal}"
      echo "NOTE: Enabling Virtualization will layer virt-manager and qemu"
      echo "      this will slow down system updates by a lot."
      OPTION=$(Choose \
        "Enable Virtualization" \
        "Disable Virtualization" \
        "Add $USER to libvirt group" \
        "Enable VFIO drivers" \
        "Disable VFIO drivers" \
        "Enable kvmfr module" \
      )
    fi
    if [[ "${OPTION,,}" =~ (^enable[[:space:]]virtualization|virt-on) ]]; then
      virt_test=$(rpm-ostree status | grep -A 4 "●" | grep "virt-manager")
      if [[ -z ${virt_test} ]]; then
        echo "Installing QEMU and virt-manager..."
        rpm-ostree install -y virt-manager edk2-ovmf qemu
        rpm-ostree kargs \
        --append-if-missing="kvm.ignore_msrs=1" \
        --append-if-missing="kvm.report_ignored_msrs=0"
        echo 'Please re-run "ujust setup-virtualization" after the reboot to enable libvirtd service'
      fi
    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]virtualization|virt-off) ]]; then
      virt_test=$(rpm-ostree status | grep -A 4 "●" | grep "virt-manager")
      if [[ ${virt_test} ]]; then
        if [ "$(systemctl is-enabled libvirtd.service)" == "enabled" ]; then
          echo "${red}Disabling${n} libvirtd before removal"
          sudo systemctl disable --now libvirtd 2> /dev/null
        fi
        echo "Removing QEMU and virt-manager..."
        rpm-ostree remove -y virt-manager edk2-ovmf qemu
        rpm-ostree kargs \
        --delete-if-present="kvm.ignore_msrs=1" \
        --delete-if-present="kvm.report_ignored_msrs=0"
        echo 'Please re-run "ujust enable-virtualization" after the reboot to finish setup'
      fi
    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]vfio|vfio-on) ]]; then
      # Check if we are running on a Steam Deck
      if /usr/libexec/hwsupport/valve-hardware; then
        echo "IOMMU is not supported on Steam Deck"
        exit 0
      fi
      echo "Enabling VFIO..."
      VIRT_TEST=$(rpm-ostree kargs)
      CPU_VENDOR=$(grep "vendor_id" "/proc/cpuinfo" | uniq | awk -F": " '{ print $2 }')
      VENDOR_KARG="unset"
      if [[ ${VIRT_TEST} == *kvm.report_ignored_msrs* ]]; then
        echo 'add_drivers+=" vfio vfio_iommu_type1 vfio-pci "' | sudo tee /etc/dracut.conf.d/vfio.conf
        rpm-ostree initramfs --enable
        if [[ ${CPU_VENDOR} == "AuthenticAMD" ]]; then
          VENDOR_KARG="amd_iommu=on"
        elif [[ ${CPU_VENDOR} == "GenuineIntel" ]]; then
          VENDOR_KARG="intel_iommu=on"  
        fi
        if [[ ${VENDOR_KARG} == "unset" ]]; then
          echo "Failed to get CPU vendor, exiting..."
          exit 1
        else
          rpm-ostree kargs \
            --append-if-missing="${VENDOR_KARG}" \
            --append-if-missing="iommu=pt" \
            --append-if-missing="rd.driver.pre=vfio_pci" \
            --append-if-missing="vfio_pci.disable_vga=1"
          echo "VFIO will be enabled on next boot, make sure you enable IOMMU, VT-d or AMD-v in your BIOS!"
          echo "Please understand that since this is such a niche use case, support will be very limited!"
          echo "To add your unused/second GPU device ids to the vfio driver by running"
          echo 'rpm-ostree kargs --append-if-missing="vfio-pci.ids=xxxx:yyyy,xxxx:yyzz"'
          echo "NOTE: Your second GPU will not be usable by the host after you do this!"
        fi
      fi
    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]vfio|vfio-off) ]]; then
      # Check if we are running on a Steam Deck
      if /usr/libexec/hwsupport/valve-hardware; then
        echo "IOMMU is not supported on Steam Deck"
        exit 0
      fi
      echo ""
      echo "Make sure you have ${b}disabled autostart of all VMs using VFIO${n} before continuing!"
      CONFIRM=$(Choose Cancel Continue)
      if [ "$CONFIRM" == "Continue" ]; then
        echo "Disabling VFIO..."
        VFIO_IDS="$(rpm-ostree kargs | sed -E 's/.+(vfio_pci.ids=.+\s)/\1/' | awk '{ print $1 }' | grep vfio_pci.ids)"
        VFIO_IDS_KARG=""
        if [ -n "$VFIO_IDS" ]; then
          echo "Found VFIO ids in kargs, adding the below line to removal list"
          echo "$VFIO_IDS"
          VFIO_IDS_KARG="--delete-if-present=\"$VFIO_IDS\""
        fi
        echo "Removing dracut modules"
        sudo rm /etc/dracut.conf.d/vfio.conf
        rpm-ostree initramfs --enable
        rpm-ostree kargs \
        --delete-if-present="iommu=pt" \
        --delete-if-present="iommu=on" \
        --delete-if-present="amd_iommu=on" \
        --delete-if-present="intel_iommu=on" \
        --delete-if-present="rd.driver.pre=vfio_pci" \
        --delete-if-present="vfio_pci.disable_vga=1" \
        --delete-if-present="vfio_pci.disable_vga=0" \
        $VFIO_IDS_KARG
      fi
    elif [[ "${OPTION,,}" =~ kvmfr ]]; then
      # Check if we are running on a Steam Deck
      if /usr/libexec/hwsupport/valve-hardware; then
        echo "IOMMU is not supported on Steam Deck"
        exit 0
      fi
      echo "$(Urllink "https://looking-glass.io/docs/rc/ivshmem_kvmfr/#libvirt" "This module") along with $(Urllink "https://looking-glass.io" "Looking Glass") is very experimental and not recommended for production use!"
      echo "The ublue team packages the kvmfr module only because it has to be supplied with the system image while using an atomic desktop."
      echo "If you do plan to use Looking Glass, please $(Urllink "https://universal-blue.discourse.group/docs?topic=956" "follow the guide here") on how to compile it for your system."
      echo "To use the kvmfr module after enabling it, just add and edit the xml for libvirt from the documentation in the first link."
      echo "Since we package the kvmfr module please open kvmfr related issues you have on Bazzite"
      echo "in the $(Urllink "https://discord.bazzite.gg/" "Bazzite Discord") or the $(Urllink "https://github.com/ublue-os/bazzite/issues" "Bazzite Github issue tracker")."
      echo "~ @HikariKnight"
      CONFIRM=$(Choose Ok Cancel)
      if [ "$CONFIRM" == "Cancel" ]; then
        exit 0
      fi
      echo ""
      echo "Setting up kvmfr module so it loads next boot"
      sudo bash -c 'cat << KVMFR_DRACUT > /etc/dracut.conf.d/kvmfr.conf
    install_items+=" /etc/modprobe.d/kvmfr.conf "
    KVMFR_DRACUT'
      sudo bash -c "cat << KVMFR_MODPROBE > /etc/modprobe.d/kvmfr.conf
    options kvmfr static_size_mb=128
    KVMFR_MODPROBE"
      echo "Adding udev rule for /dev/kvmfr0"
      sudo bash -c 'cat << KVMFR_UDEV > /etc/udev/rules.d/99-kvmfr.rules
    SUBSYSTEM=="kvmfr", OWNER="'$USER'", GROUP="qemu", MODE="0660"
    KVMFR_UDEV'
      echo "Adding /dev/kvmfr0 to qemu cgroup_device_acl"
      sudo perl -0777 -pi -e 's/
    #cgroup_device_acl = \[
    #    "\/dev\/null", "\/dev\/full", "\/dev\/zero",
    #    "\/dev\/random", "\/dev\/urandom",
    #    "\/dev\/ptmx", "\/dev\/kvm",
    #    "\/dev\/userfaultfd"
    #\]
    /
    cgroup_device_acl = \[
        "\/dev\/null", "\/dev\/full", "\/dev\/zero",
        "\/dev\/random", "\/dev\/urandom",
        "\/dev\/ptmx", "\/dev\/kvm",
        "\/dev\/userfaultfd", "\/dev\/kvmfr0"
    \]
    /' /etc/libvirt/qemu.conf
      echo "Adding SELinux context record for /dev/kvmfr0"
      sudo semanage fcontext -a -t svirt_tmpfs_t /dev/kvmfr0
      echo "Adding SELinux access rules for /dev/kvmfr0"
      if [ ! -d "$HOME/.config/selinux_te/mod" ]; then
        mkdir -p "$HOME/.config/selinux_te/mod"
      fi
      if [ ! -d "$HOME/.config/selinux_te/pp" ]; then
        mkdir -p "$HOME/.config/selinux_te/pp"
      fi
      bash -c "cat << KVMFR_SELINUX > $HOME/.config/selinux_te/kvmfr.te
    module kvmfr 1.0;

    require {
        type device_t;
        type svirt_t;
        class chr_file { open read write map };
    }

    #============= svirt_t ==============
    allow svirt_t device_t:chr_file { open read write map };
    KVMFR_SELINUX"
      echo "This is the type enforcement we wrote for SELinux and you can find it in $HOME/.config/selinux_te/kvmfr.te"
      echo "#======= start of kvmfr.te ======="
      cat "$HOME/.config/selinux_te/kvmfr.te"
      echo "#======== end of kvmfr.te ========"
      checkmodule -M -m -o "$HOME/.config/selinux_te/mod/kvmfr.mod" "$HOME/.config/selinux_te/kvmfr.te"
      semodule_package -o "$HOME/.config/selinux_te/pp/kvmfr.pp" -m "$HOME/.config/selinux_te/mod/kvmfr.mod"
      sudo semodule -i "$HOME/.config/selinux_te/pp/kvmfr.pp"
      echo "Loading kvmfr module so you do not have to reboot to use it the first time"
      sudo modprobe kvmfr static_size_mb=128
      sudo chown $USER:qemu /dev/kvmfr0
      echo ""
      echo "Kvmfr0 $(Urllink "https://looking-glass.io/docs/B7-rc1/install_libvirt/#determining-memory" "static size is set to 128mb by default")"
      echo "this will work with up to 4K SDR resolutiion, as most dummy plugs go up to 4K"
      echo "some games will try use the adapters max resolution on first boot and cause issues if the value is too low."
      echo "Most ghost display adapters max out at 4k, hence the default value of 128mb."
      echo ""
      echo "If you need to change it to a different value"
      echo "you can do that in /etc/modprobe.d/kvmfr.conf"
      echo "$(Urllink "https://looking-glass.io/docs/rc/ivshmem_kvmfr/#libvirt" "Please read official documentation for kvmfr for how to use it")"
      echo ""
      echo "Press OK to start the process of regenerating your initramfs, this will take a long time"
      echo "and there is no good way to track progress for it, if anything is wrong it will error out."
      echo "${b}NOTE: You can start using kvmfr right now without rebooting, but you will need to regenerate initramfs for it to auto load next boot.${n}"
      CONFIRM=$(Choose OK)
      rpm-ostree initramfs --enable
    elif [[ "${OPTION,,}" =~ group ]]; then
      if ! grep -q "^libvirt" /etc/group; then
        grep '^libvirt' /usr/lib/group | sudo tee -a /etc/group > /dev/null
      fi
      sudo usermod -aG libvirt $USER
    fi
# Placeholder if empty
########################
### bluefin-apps.just
########################
## Standardized verbs
# configure- = configure something that is pre-installed on the image
# install-   = install something, no uninstall or configuration provided
# setup-     = install something and also provide configuration and/or uninstallation options
# toggle-    = turn something on/off, logic can be automatic or manual selection
# fix-       = apply fix/patch/workaround for something
# foo        = no verb is used for shortcuts or something deemed important enough to use a super memorable name

# Install "fleek" set of packages for brew | none, low, default, high
install-brew-fleek level="high":
    #!/usr/bin/env bash
    curl --proto '=https' --tlsv1.2 -sSf -L https://brew.getfleek.dev/s/fleek | bash -s -- {{ level }}

# Enable Cockpit for web-based system management | https://cockpit-project.org/
setup-cockpit ACTION="":
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    COCKPIT_SERVICE_STATUS="$(systemctl is-enabled cockpit.service)"
    if [ "$COCKPIT_SERVICE_STATUS" == "enabled" ]; then
      COCKPIT_SERVICE_STATUS="${green}${b}Enabled${n}"
    elif [ "$COCKPIT_SERVICE_STATUS" == "disabled" ]; then
      COCKPIT_SERVICE_STATUS="${red}${b}Disabled${n}"
    else
      COCKPIT_SERVICE_STATUS="${invert}${b}Not Installed${n}"
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-cockpit <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'install' to select Install Cockpit"
      echo "  Use 'enable' to select Enable Cockpit"
      echo "  Use 'disable' to select Disable Cockpit"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Cockpit Setup${normal}"
      echo "Cockpit service is currently: $COCKPIT_SERVICE_STATUS"
      if [[ "${COCKPIT_SERVICE_STATUS}" =~ "Not Installed" ]]; then
        OPTION=$(Choose "Install Cockpit" "Cancel")
      else
        OPTION=$(Choose "Enable Cockpit" "Disable Cockpit")
      fi
    fi
    if [[ "${OPTION,,}" =~ ^install ]]; then
      echo 'Installing Cockpit'
      echo 'PasswordAuthentication yes' | sudo tee /etc/ssh/sshd_config.d/02-enable-passwords.conf
      sudo systemctl try-restart sshd
      sudo systemctl enable --now sshd
      sudo podman container runlabel --name cockpit-ws RUN quay.io/cockpit/ws
      sudo podman container runlabel INSTALL quay.io/cockpit/ws
      OPTION="Enable Cockpit"
    fi
    if [[ "${OPTION,,}" =~ ^enable ]]; then
      echo "${green}${b}Enabling${n} Cockpit"
      sudo systemctl enable cockpit.service
      echo "$(Urllink "http://localhost:9090" "Open Cockpit${n}") -> http://localhost:9090"
    elif [[ "${OPTION,,}" =~ ^disable ]]; then
      echo "${red}${b}Disabling${n} Cockpit"
      sudo systemctl disable cockpit.service
      echo "Cockpit has been ${b}${red}disabled${n}"
    fi

# Install JetBrains Toolbox | https://www.jetbrains.com/toolbox-app/
install-jetbrains-toolbox:
    #!/usr/bin/env bash
    pushd "$(mktemp -d)"
    echo "Get latest JetBrains Toolbox version"
    # Get the json with latest releases
    curl -sSfL -o releases.json "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"
    # Extract information
    BUILD_VERSION=$(jq -r '.TBA[0].build' ./releases.json)
    DOWNLOAD_LINK=$(jq -r '.TBA[0].downloads.linux.link' ./releases.json)
    CHECKSUM_LINK=$(jq -r '.TBA[0].downloads.linux.checksumLink' ./releases.json)
    echo "Installing JetBrains Toolbox ${BUILD_VERSION}"
    curl -sSfL -O "${DOWNLOAD_LINK}"
    curl -sSfL "${CHECKSUM_LINK}" | sha256sum -c
    tar zxf jetbrains-toolbox-"${BUILD_VERSION}".tar.gz
    echo "Launching JetBrains Toolbox"
    ./jetbrains-toolbox-"${BUILD_VERSION}"/jetbrains-toolbox

# Add atuin
install-atuin:
    #!/usr/bin/bash 
    shell=$(basename $SHELL) 
    if test $shell = "fish"; then 
        echo "Adding atuin to your config.fish"
        printf '\nif status is-interactive\n\tif type -q atuin\n\t\tatuin init fish | source\n\tend\nend\n' >> ${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish
    elif test $shell = "zsh"; then 
        echo "Adding atuin to your .zshrc"
        printf '\n[[ "$(command -v atuin)" ]] && eval "$(atuin init zsh)"\n' >> ${ZDOTDIR:-$HOME}/.zshrc 
    elif test $shell = "bash"; then 
        echo "Adding bash-prexec and atuin to your .bashrc" 
        printf '\n[[ -f /usr/share/bash-prexec ]] && source /usr/share/bash-prexec\n[[ "$(command -v atuin)" ]] && eval "$(atuin init bash)"\n' >> ~/.bashrc
    fi

alias incus := install-incus

# Install and configure Incus
install-incus:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_IMAGE=$(rpm-ostree status -b --json | jq -r '.deployments[0]."container-image-reference"')
    if grep -Eq "bluefin-dx|aurora-dx|ghcr.io/asirshahid/myos" <<< $CURRENT_IMAGE
    then
        echo 'Installing and configuring Incus.'
        /usr/libexec/bluefin-incus
    else
        echo "Developer mode is currently ${b}${red}Disabled${n}."
        echo "Run \"just devmode\" to turn on Developer mode."
        exit
    fi
########################
### bluefin-system.just
########################
## Standardized verbs
# configure- = configure something that is pre-installed on the image
# install-   = install something, no uninstall or configuration provided
# setup-     = install something and also provide configuration and/or uninstallation options
# toggle-    = turn something on/off, logic can be automatic or manual selection
# fix-       = apply fix/patch/workaround for something
# foo        = no verb is used for shortcuts or something deemed important enough to use a super memorable name

# Run a one minute system benchmark
benchmark:
    echo 'Running a 1 minute benchmark ...'
    cd /tmp && stress-ng --matrix 0 -t 1m --times

# Configure Bluefin-CLI Terminal Experience with Brew
bluefin-cli:
    @brew bundle --file /usr/share/ublue-os/homebrew/bluefin-cli.Brewfile --no-lock
    echo 'Installation complete ... please close and reopen your terminal!'

# Configure Bluefin-CLI Terminal Experience
[private]
bluefin-cli-container:
    @/usr/libexec/enable-bluefin-cli.sh

# Configure Terminal Experience
[private]
configure-terminal:
    @/usr/libexec/configure-terminal.sh

# Toggle between Bluefin and the Developer Experience
devmode:
    #!/usr/bin/env bash
    CURRENT_IMAGE=$(rpm-ostree status -b --json | jq -r '.deployments[0]."container-image-reference"')
    if grep -q "/var/ublue-os/image" <<< $CURRENT_IMAGE
    then
        echo ""
        echo "Before we can switch to the Bluefin Developer Experience"
        echo "the current system needs an update. Please run 'just update'"
        echo "and reboot your system when the update is finished."
        exit
    fi
    if grep -q "dx" <<< $CURRENT_IMAGE
    then
        CURRENT_STATE="enabled"
    else
        CURRENT_STATE="disabled"
    fi
    echo "Developer mode is currently ${CURRENT_STATE}"
    echo "Enable or Disable developer mode"
    OPTION=$(gum choose Enable Disable)
    if [ "$OPTION" = "Enable" ]
    then
        if [ "$CURRENT_STATE" = "enabled" ]
        then
            echo "You are already on a developer image"
        else
            echo "Rebasing to a developer image"
            if [[ "${CURRENT_IMAGE}" =~ "bluefin" ]]; then
              NEW_IMAGE=$(echo $CURRENT_IMAGE | sed "s/bluefin/bluefin-dx/")
            elif [[ "${CURRENT_IMAGE}" =~ "aurora" ]]; then
              NEW_IMAGE=$(echo $CURRENT_IMAGE | sed "s/aurora/aurora-dx/")
            fi
            rpm-ostree rebase $NEW_IMAGE
        fi
    elif [ "$OPTION" = "Disable" ]
    then
        if [ "$CURRENT_STATE" = "enabled" ]
        then
            echo "Rebasing to a non developer image"
            if [[ "${CURRENT_IMAGE}" =~ "bluefin" ]]; then
              NEW_IMAGE=$(echo $CURRENT_IMAGE | sed "s/bluefin-dx/bluefin/")
            elif [[ "${CURRENT_IMAGE}" =~ "aurora" ]]; then
              NEW_IMAGE=$(echo $CURRENT_IMAGE | sed "s/aurora-dx/aurora/")
            fi
            rpm-ostree rebase $NEW_IMAGE
        else
            echo "You are currently not on a developer image"
        fi
    fi

# Switch to a different shell
configure-shell ACTION="":
    #!/bin/bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_SHELL="$(cat /etc/passwd | grep ":$UID:" | cut '-d:' '-f7')"
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust shell <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'fish' to select fish"
      echo "  Use 'zsh' to select zsh"
      echo "  Use 'bash' to select bash"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Shell configuration${normal}"
      echo "${USER}'s shell is currently ${CURRENT_SHELL}"
      OPTION=$(Choose "fish" "zsh" "bash")
    fi
    if [ -z "$OPTION" ]; then
      exit 0
    else
      sudo usermod $USER --shell /usr/bin/$OPTION 
      printf "${USER}'s shell is now %s.\n" "$(cat /etc/passwd | grep ":$UID:" | cut '-d:' '-f7')"
    fi

# Install recommended GNOME extensions
get-gnome-extensions:
    pip install --upgrade gnome-extensions-cli
    gext install nightthemeswitcher@romainvigier.fr
    gext install pano@elhan.io
    gext install weatheroclock@CleoMenezesJr.github.io
    gext install paperwm@paperwm.github.com

# Enable or Disable Gnome-VRR
toggle-gnome-vrr:
    #!/usr/bin/env bash
    if gsettings get org.gnome.mutter experimental-features | grep -q "variable-refresh-rate"
    then
      CURRENT_STATE="Enabled"
    else
      CURRENT_STATE="Disabled"
    fi
    echo "Gnome-VRR is currently ${CURRENT_STATE}"
    echo "Enable or Disable Gnome-VRR"
    OPTION=$(gum choose Enable Disable)
    if [ "$OPTION" = "Enable" ]
    then
      echo "Enabling Gnome-VRR"
      gsettings set org.gnome.mutter experimental-features "['variable-refresh-rate','scale-monitor-framebuffer']"
    elif [ "$OPTION" = "Disable" ]
    then
      echo "Disabling Gnome-VRR"
      gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
    fi
    echo "To apply the changes make sure you logout and restart your session"

# Ptyxis terminal transparency
ptyxis-transparency opacity="0.95":
    #!/usr/bin/env bash
    set -euxo pipefail
    if [[ -n "$(echo "{{ opacity }}" | grep -v '^[.0-9]*$')" ]]; then
      printf "Value must be numeric: %s.\n" "{{ opacity }}"
    elif [[ $(echo "0<{{ opacity }} && 1>={{ opacity }}" | bc -q) -eq 1 ]]; then
      raw="$(gsettings get org.gnome.Ptyxis profile-uuids)"
      uuids="$(sed -En 's|[^0-9a-z]*||g; s|([0-9a-z]{32})|\1\n|gp' <<<${raw})"
      for i in ${uuids}; do
        location="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${i}/"
        gsettings set "${location}" opacity "{{ opacity }}"; done
      printf "Ptyxis opacity is now %s.\n" "{{ opacity }}"
    else
      printf "Value must be greater than 0 and less than or equal to 1: %s.\n" "{{ opacity }}"
    fi

# Configure docker,incus-admin,lxd,libvirt container manager permissions
dx-group:
    sudo usermod -aG docker $USER
    sudo usermod -aG incus-admin $USER
    sudo usermod -aG lxd $USER
    sudo usermod -aG libvirt $USER
    @echo "Logout to use docker, incus-admin, lxd, libvirt"

# Configure system to use vfio and kvmfr
configure-vfio ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_IMAGE=$(rpm-ostree status -b --json | jq -r '.deployments[0]."container-image-reference"')
    if grep -q "dx" <<< $CURRENT_IMAGE
    then
      DEVMODE="enabled"
    else
      DEVMODE="disabled"
    fi
    if [ "$DEVMODE" == "disabled" ]; then
      echo 'Please run "ujust devmode" first'
      exit 0
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-vfio <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'vfio-on' to select Enable VFIO drivers"
      echo "  Use 'vfio-off' to select Disable VFIO drivers"
      echo "  Use 'kvmfr' to select Autocreate Looking-Glass shm"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}VFIO and kvmfr Configuration${normal}"
      echo "This is only used for GPU passthrough of a secondary dGPU."
      echo "It will enable vfio and configure kvmfr for use with $(Urllink "https://looking-glass.io" "Looking Glass")"
      echo "If you do not plan to use any of this then press ESC."
      echo "${bold}NOTE:${normal} Since this is a niche use case, support will be ${b}very limited${n}"
      OPTION=$(Choose \
        "Enable VFIO drivers" \
        "Disable VFIO drivers" \
        "Enable kvmfr module" \
      )
    fi
    if [[ "${OPTION,,}" =~ (^enable[[:space:]]vfio|vfio-on) ]]; then
      echo "Enabling VFIO..."
      VIRT_TEST=$(rpm-ostree kargs)
      CPU_VENDOR=$(grep "vendor_id" "/proc/cpuinfo" | uniq | awk -F": " '{ print $2 }')
      VENDOR_KARG="unset"
      if [[ ${VIRT_TEST} == *kvm.report_ignored_msrs* ]]; then
        echo 'add_drivers+=" vfio vfio_iommu_type1 vfio-pci "' | sudo tee /etc/dracut.conf.d/vfio.conf
        rpm-ostree initramfs --enable
        if [[ ${CPU_VENDOR} == "AuthenticAMD" ]]; then
          VENDOR_KARG="amd_iommu=on"
        elif [[ ${CPU_VENDOR} == "GenuineIntel" ]]; then
          VENDOR_KARG="intel_iommu=on"  
        fi
        if [[ ${VENDOR_KARG} == "unset" ]]; then
          echo "Failed to get CPU vendor, exiting..."
          exit 1
        else
          rpm-ostree kargs \
            --append-if-missing="${VENDOR_KARG}" \
            --append-if-missing="iommu=pt" \
            --append-if-missing="rd.driver.pre=vfio_pci" \
            --append-if-missing="vfio_pci.disable_vga=1"
          echo "VFIO will be enabled on next boot, make sure you enable IOMMU, VT-d or AMD-v in your BIOS!"
          echo "Please understand that since this is such a niche use case, support will be very limited!"
          echo "To add your unused/second GPU device ids to the vfio driver by running"
          echo 'rpm-ostree kargs --append-if-missing="vfio-pci.ids=xxxx:yyyy,xxxx:yyzz"'
          echo "NOTE: Your second GPU will not be usable by the host after you do this!"
        fi
      fi
    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]vfio|vfio-off) ]]; then
      echo ""
      echo "Make sure you have ${b}disabled autostart of all VMs using VFIO${n} before continuing!"
      CONFIRM=$(Choose Cancel Continue)
      if [ "$CONFIRM" == "Continue" ]; then
        echo "Disabling VFIO..."
        VFIO_IDS="$(rpm-ostree kargs | sed -E 's/.+(vfio_pci.ids=.+\s)/\1/' | awk '{ print $1 }' | grep vfio_pci.ids)"
        VFIO_IDS_KARG=""
        if [ -n "$VFIO_IDS" ]; then
          echo "Found VFIO ids in kargs, adding the below line to removal list"
          echo "$VFIO_IDS"
          VFIO_IDS_KARG="--delete-if-present=\"$VFIO_IDS\""
        fi
        echo "Removing dracut modules"
        sudo rm /etc/dracut.conf.d/vfio.conf
        rpm-ostree initramfs --enable
        rpm-ostree kargs \
        --delete-if-present="iommu=pt" \
        --delete-if-present="iommu=on" \
        --delete-if-present="amd_iommu=on" \
        --delete-if-present="intel_iommu=on" \
        --delete-if-present="rd.driver.pre=vfio_pci" \
        --delete-if-present="vfio_pci.disable_vga=1" \
        --delete-if-present="vfio_pci.disable_vga=0" \
        $VFIO_IDS_KARG
      fi
    elif [[ "${OPTION,,}" =~ kvmfr ]]; then
      sudo /usr/libexec/bluefin-dx-kvmfr-setup
    fi

# Change automatic power profile switching behavior
configure-auto-power-profile ACTION="help":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-auto-power-profile <option>"
      echo "  Use 'enable' to allow automatic power profile switching based on power state
      echo "  Use 'disable' to prevent automatic power profile switching based on power state
      exit 0
    elif [[ "${OPTION,,}" =~ enable ]]; then
      gnome-extensions enable auto-power-profile@dmy3k.github.io
    elif [[ "${OPTION,,}" =~ disable ]]; then
      gnome-extensions disable auto-power-profile@dmy3k.github.io
    fi

# Install system flatpaks for rebasers
[private]
install-system-flatpaks:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        FLATPAKS="bluefin_flatpaks/flatpaks"
    elif [[ ${BASE_IMAGE_NAME} == 'kinoite' ]]; then
        FLATPAKS="aurora_flatpaks/flatpaks"
    fi
    FLATPAK_LIST="$(curl https://raw.githubusercontent.com/ublue-os/bluefin/main/${FLATPAKS} | tr '\n' ' ')"
    flatpak --system -y install --or-update ${FLATPAK_LIST}

# Configure grub bootmenu visibility
#configure-grub:
#    /usr/libexec/configure-grub.sh

update-ng:
    echo "Note: This command doesn't work if you have locally layered packages" 
    sudo bootc upgrade
    flatpak update -y
    brew upgrade
########################
### bluefin-tools.just
########################
## Standardized verbs
# configure- = configure something that is pre-installed on the image
# install-   = install something, no uninstall or configuration provided
# setup-     = install something and also provide configuration and/or uninstallation options
# toggle-    = turn something on/off, logic can be automatic or manual selection
# fix-       = apply fix/patch/workaround for something
# foo        = no verb is used for shortcuts or something deemed important enough to use a super memorable name

# Run pytorch
pytorch:
    echo 'Follow the prompts and check the tutorial: https://docs.anaconda.com/free/anaconda/jupyter-notebooks/'
    podman pull docker.io/continuumio/miniconda3
    podman run -i -t -p 8888:8888 docker.io/continuumio/miniconda3 /bin/bash -c "/opt/conda/bin/conda install jupyter -y --quiet && mkdir \
    /opt/notebooks && /opt/conda/bin/jupyter notebook \
    --notebook-dir=/opt/notebooks --ip='*' --port=8888 \
    --no-browser --allow-root"

# Run Tensorflow
tensorflow:
    echo 'Follow the prompts and check the tutorial: https://www.tensorflow.org/tutorials/quickstart/beginner'
    podman pull docker.io/tensorflow/tensorflow:latest
    podman run -it -p 8888:8888 docker.io/tensorflow/tensorflow:latest-jupyter  # Start Jupyter server

# Setup a local Ollama instance in a container. Detect hardware, offer a choice if needed.
ollama:
    #!/usr/bin/env bash
    echo 'Detecting Hardware...'
    echo
    GPU_CHOICES=("Nvidia (CUDA)" "AMD (ROCm)" "CPU (slow)")
    DETECTED_OPTIONS=()
    # Detect nvidia drivers
    if which nvidia-smi > /dev/null 2>&1; then
        DETECTED_OPTIONS+=("${GPU_CHOICES[0]}")
    fi
    # Detect AMD hardware
    if lspci | grep ' VGA ' | grep -sq AMD; then
        DETECTED_OPTIONS+=("${GPU_CHOICES[1]}")
    fi
    # Nothing detected, ask the user
    if [ ${#DETECTED_OPTIONS[@]} -eq 0 ]; then
        GPU_SELECTION=$(printf '%s\n' "${GPU_CHOICES[@]}" | gum choose --select-if-one --header "Select the type of graphics card you want to use")
    else
        GPU_SELECTION=$(printf '%s\n' "${DETECTED_OPTIONS[@]}" | gum choose --select-if-one --header "Select the type of graphics card you want to use")
    fi
    echo "Selected ${GPU_SELECTION}!"
    case "$GPU_SELECTION" in
        "Nvidia (CUDA)")
            IMAGE=latest
            CUSTOM_ARGS="AddDevice=nvidia.com/gpu=all"
            ;;

        "AMD (ROCm)")
            IMAGE=rocm
            read -r -d '' CUSTOM_ARGS <<-'EOF'
    AddDevice=/dev/dri
    AddDevice=/dev/kfd
    EOF
            ;;
        *)
            IMAGE=latest
            CUSTOM_ARGS=""
            ;;
    esac

    read -r -d '' QUADLET <<-EOF
    [Unit]
    Description=The Ollama container
    After=local-fs.target

    [Service]
    Restart=always
    TimeoutStartSec=60
    # Ensure there's a userland podman.sock
    ExecStartPre=/bin/systemctl --user enable podman.socket
    # Ensure that the dir exists
    ExecStartPre=-mkdir -p %h/.ollama

    [Container]
    ContainerName=ollama
    PublishPort=11434:11434
    RemapUsers=keep-id
    RunInit=yes
    NoNewPrivileges=no
    Network=ollama.network
    Volume=%h/.ollama:/.ollama
    PodmanArgs=--userns=keep-id
    PodmanArgs=--group-add=keep-groups
    PodmanArgs=--ulimit=host
    PodmanArgs=--security-opt=label=disable
    PodmanArgs=--cgroupns=host

    Image=docker.io/ollama/ollama:${IMAGE}
    ${CUSTOM_ARGS}

    [Install]
    RequiredBy=multi-user.target
    EOF
    if [  ! -f ~/.config/containers/systemd/ollama.container ]; then
        mkdir -p ~/.config/containers/systemd
        echo "${QUADLET}" > ~/.config/containers/systemd/ollama.container
    else
        echo "Ollama container already exists, skipping..."
    fi

    read -r -d '' QUADLET_NETWORK <<-EOF
    [Network]
    NetworkName=ollama
    EOF
    if [  ! -f ~/.config/containers/systemd/ollama.network ]; then
        mkdir -p ~/.config/containers/systemd
        echo "${QUADLET_NETWORK}" > ~/.config/containers/systemd/ollama.network
    else
        echo "Ollama network already exists, skipping..."
    fi

    systemctl --user daemon-reload
    systemctl --user start ollama.service || echo "Error starting Ollama Quadlet."
    echo "Please install the ollama cli via \`brew install ollama\`"

# Setup a local Ollama WebUI in a container
ollama-web: ollama
    #!/usr/bin/env bash

    read -r -d '' QUADLET <<-EOF
    [Unit]
    Description=An Ollama WebUI container
    After=network-online.target ollama.service
    Requires=ollama.service

    [Container]
    Image=ghcr.io/open-webui/open-webui:latest
    AutoUpdate=registry
    ContainerName=ollama-web
    Environment=OLLAMA_BASE_URL=http://ollama:11434
    Environment=WEBUI_SECRET_KEY=abc123
    Environment=DEFAULT_USER_ROLE=admin
    # Open WebUI does not allow access without a user account, nor does it allow
    # account creation via environment variables.
    Environment=ENABLE_SIGNUP=true
    PublishPort=8080:8080
    Network=ollama.network

    [Service]
    TimeoutStartSec=900

    [Install]
    WantedBy=multi-user.target
    EOF
    if [  ! -f ~/.config/containers/systemd/ollama-web.container ]; then
        mkdir -p ~/.config/containers/systemd
        echo "${QUADLET}" > ~/.config/containers/systemd/ollama-web.container
    else
        echo "Ollama WebUI container already exists, skipping..."
    fi
    systemctl --user daemon-reload
    systemctl --user start ollama-web.service

# Run pytorch
ags-deps:
    sudo npm -g install bun
    sudo npm -g install sass
    brew install sass/sass/sass
    cargo install matugen
    pip3 install materialyoucolor --upgrade
    pip3 install material-color-utilities-python --upgrade
    pip3 install build --upgrade
    pip3 install 'pillow<10.0.0,>=9.2.0' --upgrade
    pip3 install pywal --upgrade
    pip3 install wheel --upgrade
    pip3 install setuptools-scm --upgrade
