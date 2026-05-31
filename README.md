# myos &nbsp; [![build-ublue](https://github.com/asirshahid/myos/actions/workflows/build.yml/badge.svg)](https://github.com/asirshahid/myos/actions/workflows/build.yml)

`myos` is a personal [BlueBuild](https://blue-build.org/) custom image based on
[`ghcr.io/ublue-os/bluefin-dx`](https://github.com/ublue-os/bluefin). It layers on
a Hyprland/Niri Wayland desktop toolkit, development libraries, messaging and
productivity Flatpaks, custom fonts, GNOME extensions, and personal dotfiles
(via [chezmoi](https://www.chezmoi.io/)).

The full set of packages, repositories, and modules is defined in
[`recipes/recipe.yml`](recipes/recipe.yml).

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for instructions on
setting up your own repository based on this template.

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

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## ISO

If built on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/asirshahid/myos
```
