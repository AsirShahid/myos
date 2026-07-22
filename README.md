# myos &nbsp; [![build-ublue](https://github.com/asirshahid/myos/actions/workflows/build.yml/badge.svg)](https://github.com/asirshahid/myos/actions/workflows/build.yml)

My personal OS image, built with [BlueBuild](https://blue-build.org/) on top of
[Bluefin DX](https://projectbluefin.io/). On top of the base it adds:

- **niri** (scrollable-tiling Wayland compositor) plus its session stack
  (hyprlock, hypridle, SwayNotificationCenter, AGS/aylurs-gtk-shell) and wlroots
  tooling (fuzzel, grim/slurp, dunst, swappy, …) alongside the stock GNOME desktop
- **GNOME tweaks**: pop-shell tiling, Blur my Shell, Night Theme Switcher,
  Caffeine, Bluetooth Battery Meter, and Copyous, enabled via gschema override,
  plus the Bibata-Modern-Ice cursor theme
- **VPNs**: Mullvad, Windscribe (with `ujust setup-windscribe`), GlobalProtect
  (openconnect), and OpenVPN/OpenConnect NetworkManager plugins
- **Apps**: a Flathub set (Steam, Obsidian, Bitwarden, LibreOffice, Discord,
  Telegram, Element, …), [Beeper](https://www.beeper.com/) (pinned AppImage),
  [claude-cowork-linux](https://github.com/johnzfitch/claude-cowork-linux) via
  the `/usr/bin/claude-cowork` launcher, and Anthropic's claude-science
  (`/usr/bin/claude-science`) with the Modal CLI as its compute backend
- **Waydroid** for Android apps, with Bazzite's setup recipe
  (`ujust setup-waydroid`) and firewalld networking fix baked in
- **CLI**: starship, helix, kitty, emacs, atuin, fzf, Nerd Fonts, and Homebrew
  with automatic updates
- Dotfiles applied for all users with
  [chezmoi](https://github.com/AsirShahid/dotfiles), and
  `power-profiles-daemon` in place of tuned-ppd

Images build daily at 17:00 UTC via GitHub Actions and are pushed to
`ghcr.io/asirshahid/myos`.

## Installation

> **Warning**  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/asirshahid/myos:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/asirshahid/myos:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag always points to the latest build. Note that the recipe
tracks `bluefin-dx:latest`, which follows the latest stable Fedora release —
so major Fedora upgrades happen automatically. Pin `image-version` in
`recipes/recipe.yml` (e.g. to `gts` or a release number) if you want to
control major upgrades manually.

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/asirshahid/myos
```
