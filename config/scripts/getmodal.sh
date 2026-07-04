#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
set -oue pipefail

# Install the Modal CLI (modal.com) as /usr/bin/modal.
#
# Modal is a Python CLI/SDK; Claude Science uses it as a remote compute backend
# (job submission to Modal's cloud CPUs/GPUs). We install it into a
# self-contained venv under /usr/lib/modal — isolated from the system
# site-packages, so no --break-system-packages — and symlink /usr/bin/modal to
# it. During the BlueBuild build /usr is writable, so the venv and its
# absolute-path entrypoint shebang (/usr/lib/modal/bin/python3) bake into the
# image and keep working at runtime where /usr is read-only. The venv's python
# is the base image's python3, so a rebuild always matches the running image.
#
# Auth is NOT baked: `modal token set` writes ~/.modal.toml per-user (a secret),
# which the modal CLI/SDK reads at runtime.
#
# Pinned so the daily image rebuild doesn't silently ship a new modal release;
# bump deliberately. Latest on PyPI: https://pypi.org/pypi/modal/json (.info.version)
MODAL_VERSION=1.5.1
MODAL_VENV=/usr/lib/modal

echo "Installing modal ${MODAL_VERSION} into ${MODAL_VENV}..."
rm -rf "${MODAL_VENV}"
python3 -m venv "${MODAL_VENV}"
"${MODAL_VENV}/bin/pip" install --no-cache-dir "modal==${MODAL_VERSION}"
ln -sf "${MODAL_VENV}/bin/modal" /usr/bin/modal

# Sanity-check the entrypoint resolves (fails the build if the venv is broken).
/usr/bin/modal --version

# Record the baked version so `ujust modal-version` can compare with upstream.
mkdir -p /usr/share/myos
echo "${MODAL_VERSION}" > /usr/share/myos/modal-version

echo 'modal installation completed'
