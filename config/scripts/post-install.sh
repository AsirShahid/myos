#!/usr/bin/env bash

set -oue pipefail

echo 'Running post-install steps...'

# tuned-ppd conflicts with power-profiles-daemon; remove it if present
rpm -q tuned-ppd &>/dev/null && dnf remove -y tuned-ppd || true
