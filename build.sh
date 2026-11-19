#!/bin/sh
# Build every package in pkgs/ and index it into repo/zpt-artix.db. Installs nothing:
# missing build deps make makepkg fail and are listed in the summary for you to install.
# Usage: ./build.sh [pkgs/<dir>/ ...]  (default: every dir). MAKEPKG_EXTRA is appended to makepkg's
# flags (container-build.sh sets "-s --noconfirm" to install build deps in its throwaway container).
# Run it through ./container-build.sh, never on a non-Artix host: packages must link against Artix libraries.
cd "$(dirname "$0")" || exit 1
export PATH=/usr/bin:$PATH  # a non-zstd "zstd" in ~/.local/bin breaks package compression
mkdir -p repo
failed=
[ $# -gt 0 ] || set -- pkgs/*/
build_one() {
  d=$1
  n=$(basename "$d")
  echo "=== $n"
  # Meta-packages and OpenRC script packages depend on packages that live only in this repo, and DKMS
  # packages build nothing but depend on dkms, so skip the dep check for all three.
  case $n in zpt-artix-*|*-dkms|*-openrc) flags=-fd ;; *) flags=-f ;; esac
  if (cd "$d" && makepkg $flags $MAKEPKG_EXTRA && for f in $(makepkg --packagelist); do [ -f "$f" ] || continue; cp "$f" ../../repo/ || exit; done); then
    echo "=== $n: OK"
  else
    echo "=== $n: FAILED"; failed="$failed $n"
  fi
}
for d in "$@"; do build_one "$d"; done
# Some packages build against another package of this repo (xlibre-input-libinput-homestead needs
# xlibre-xserver-homestead's SDK) and fail above if built first. When pacman.conf has this repo/ as
# a file:// [zpt-artix] repo (container-build.sh and CI add it), index what was built and retry the
# failed ones, so makepkg -s installs those deps from it, as long as each round builds something.
while [ -n "$failed" ] && pacman-conf --repo zpt-artix Server 2>/dev/null | grep -q '^file://'; do
  repo-add -R repo/zpt-artix.db.tar.zst repo/*.pkg.tar.zst && sudo pacman -Sy || break
  retry=$failed; failed=
  for n in $retry; do build_one "pkgs/$n/"; done
  [ "$failed" = "$retry" ] && break
done
repo-add -R repo/zpt-artix.db.tar.zst repo/*.pkg.tar.zst
echo "SUMMARY: failed:${failed:- none}"
ls repo/*.pkg.tar.zst
[ -z "$failed" ]
