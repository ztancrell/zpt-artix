#!/bin/sh
# Run build.sh in a fresh Artix container (rootless podman, removed afterwards), so packages build
# against Artix libraries, never the host's. Build deps are installed in the container only.
# Usage: ./container-build.sh [pkgs/<dir>/ ...]  (same arguments as build.sh)
# keep-id gives the container a user with your uid and gid; build.sh runs as that user (makepkg
# refuses root), so it can write pkgs/ and repo/ and the results stay owned by you.
cd "$(dirname "$0")" || exit 1
exec podman run --rm --userns=keep-id --user root -e HOST_UID="$(id -u)" -v "$PWD":/zpt-artix:Z -w /zpt-artix \
  docker.io/artixlinux/artixlinux:base-devel sh -c '
    pacman -Syu --noconfirm --needed >/dev/null || exit
    echo "#$HOST_UID ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
    sudo -u "#$HOST_UID" env HOME=/tmp MAKEPKG_EXTRA="-s --noconfirm" ./build.sh "$@"' sh "$@"
