#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
set -oue pipefail

# Install Windscribe (GUI + windscribe-cli) as an RPM.
#
# There's no upstream dnf repo, so we pull the version-pinned Fedora RPM from
# the GitHub release. GitHub release assets are mutable and dnf skips the
# vendor gpg check for an @commandline package, so TLS alone is not enough:
# pin a sha256 and verify it before installing, the same way getbeeper.sh and
# getbibata-cursor.sh do. Bump WINDSCRIBE_VERSION and WINDSCRIBE_SHA256
# together deliberately; `ujust windscribe-version` flags when a newer release
# exists. The RPM ships windscribe-helper.service, enabled via the systemd
# module in recipes/recipe.yml.
WINDSCRIBE_VERSION=2.23.12
WINDSCRIBE_SHA256=e4aa9a42c68f3c28a6565826b74ec89f4bcc66ae35bf2a6c530907d2e01fc16f

echo "Downloading Windscribe ${WINDSCRIBE_VERSION}..."
curl -fL --retry 3 --retry-delay 5 --retry-all-errors -o /tmp/windscribe.rpm \
  "https://github.com/Windscribe/Desktop-App/releases/download/v${WINDSCRIBE_VERSION}/windscribe_${WINDSCRIBE_VERSION}_amd64_fedora.rpm"
echo "${WINDSCRIBE_SHA256}  /tmp/windscribe.rpm" | sha256sum -c -

# Install the verified local RPM. dnf still treats it as @commandline and warns
# that it can't check the vendor signature; the sha256 check above is what we
# trust instead.
dnf install -y /tmp/windscribe.rpm
rm -f /tmp/windscribe.rpm

# Fail the build if the package didn't actually land (e.g. an unmet dependency
# that dnf only warned about), instead of shipping without it.
rpm -q windscribe

echo 'Windscribe installation completed'
