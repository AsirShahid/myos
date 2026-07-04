#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
set -oue pipefail

# Install Claude Science for Linux as /usr/bin/claude-science.
#
# Claude Science is Anthropic's AI workbench for scientists. The upstream
# one-liner (claude.ai/install-claude-science.sh) drops a single self-contained
# linux-x64 binary into ~/.local/bin; everything else it needs — the Python/R
# runtimes and per-user state — it sets up under ~/.claude-science on the first
# `claude-science serve`, and sign-in is interactive. So we bake only the
# binary here; the runtime and auth stay per-user at runtime.
#
# Pinned to a specific release and verified against the same sha256 the upstream
# installer checks (the operon-dist manifest.json) so the daily image rebuild
# doesn't silently ship a new beta build; bump the sha8, version and hash
# together deliberately. Resolve the current 'stable' pin with:
#   base=https://storage.googleapis.com/operon-dist-cf94a20e-f71c-413c-bd00-9e12b1fedf59/operon-releases
#   sha8=$(curl -fsSL "$base/stable"); curl -fsSL "$base/$sha8/manifest.json"
#
# Sandbox runtime deps (bubblewrap + socat) come from the dnf module — the
# binary runs without them, but claude-science's sandbox needs them at first run.
SCIENCE_SHA8=aa553de7
SCIENCE_VERSION=0.1.15
SCIENCE_SHA256=a5c966b3d07fb3e4460522d30b962c43eff7b6e15746defe0f37473b9df0a3d3
SCIENCE_BASE_URL=https://storage.googleapis.com/operon-dist-cf94a20e-f71c-413c-bd00-9e12b1fedf59/operon-releases

echo "Downloading claude-science ${SCIENCE_VERSION} (${SCIENCE_SHA8})..."
curl -fL --proto '=https' --tlsv1.2 -o /tmp/claude-science \
  "${SCIENCE_BASE_URL}/${SCIENCE_SHA8}/operon-linux-x64"
echo "${SCIENCE_SHA256}  /tmp/claude-science" | sha256sum -c -
install -m 0755 /tmp/claude-science /usr/bin/claude-science
rm -f /tmp/claude-science

# Record the baked version so `ujust claude-science-version` can compare with
# upstream.
mkdir -p /usr/share/myos
echo "${SCIENCE_VERSION}" > /usr/share/myos/claude-science-version

echo 'claude-science installation completed'
