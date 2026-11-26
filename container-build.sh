#!/bin/sh
# Run build.sh in a fresh Artix container (rootless podman, removed afterwards), so packages build
# against Artix libraries, never the host's. Build deps are installed in the container only.
# Usage: ./container-build.sh [pkgs/<dir>/ ...]  (same arguments as build.sh)
# keep-id gives the container a user with your uid and gid; build.sh runs as that user (makepkg
# refuses root), so it can write pkgs/ and repo/ and the results stay owned by you.
# k8s-file logging: podman 6 defaults to journald, which Artix (no systemd) lacks ("conmon failed").
cd "$(dirname "$0")" || exit 1
exec podman run --rm --log-driver k8s-file --userns=keep-id --user root -e HOST_UID="$(id -u)" -v "$PWD":/zpt-artix:Z -w /zpt-artix \
  docker.io/artixlinux/artixlinux:base-devel sh -c '
    pacman -Syu --noconfirm --needed >/dev/null || exit
    # repo/ as a local repo: build.sh retries packages that need another package of this repo.
    printf "\n[zpt-artix]\nSigLevel = Optional TrustAll\nServer = file:///zpt-artix/repo\n" >> /etc/pacman.conf
    # An empty sync db until build.sh syncs it: pacman -S refuses to run with a repo that has none.
    tar -czf /var/lib/pacman/sync/zpt-artix.db -T /dev/null
    echo "#$HOST_UID ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
    sudo -u "#$HOST_UID" env HOME=/tmp MAKEPKG_EXTRA="-s --noconfirm" ./build.sh "$@"' sh "$@"
