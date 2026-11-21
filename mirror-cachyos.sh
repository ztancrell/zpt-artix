#!/bin/sh
# Mirror CachyOS's signed EAC kernel and its signing key package into repo/, unchanged (never rebuilt).
# Downloads each package and its .sig from the CachyOS x86_64 `cachyos` repo, verifies the signature
# against CachyOS's packager key (keys/cachyos.asc, pinned by fingerprint below), refuses on any
# failure, then copies the files into repo/ and indexes them into repo/zpt-artix.db.
# Usage: ./mirror-cachyos.sh  (MIRROR overrides the mirror). For a new kernel, edit PKGS and run again.
cd "$(dirname "$0")" || exit 1
export PATH=/usr/bin:$PATH  # a non-zstd "zstd" in ~/.local/bin breaks db compression
PKGS="linux-cachyos-eac-7.3.5-2-x86_64 cachyos-eac-signing-key-1-2-any"
MIRROR=${MIRROR:-https://cdn77.cachyos.org/repo/x86_64/cachyos}
# CachyOS <admin@cachyos.org>, from cachyos-keyring 20240331-1 (/usr/share/pacman/keyrings/cachyos.gpg).
FPR=882DCFE48E2051D48E2562ABF3B607488DB35A47
mkdir -p repo
tmp=$(mktemp -d "$PWD/repo/.mirror.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
gpg --dearmor < keys/cachyos.asc > "$tmp/cachyos.gpg" || exit 1  # gpgv reads only binary keyrings
files=
for p in $PKGS; do
  f=$p.pkg.tar.zst
  echo "=== $f"
  curl -fL --retry 3 -o "$tmp/$f" "$MIRROR/$f" && curl -fL --retry 3 -o "$tmp/$f.sig" "$MIRROR/$f.sig" || exit 1
  # gpgv exits non-zero on a bad signature; VALIDSIG's last field is the signing primary key.
  gpgv --status-fd 1 --keyring "$tmp/cachyos.gpg" "$tmp/$f.sig" "$tmp/$f" 2>/dev/null \
    | grep -q "^\[GNUPG:\] VALIDSIG .* $FPR\$" || { echo "=== $f: BAD SIGNATURE, refusing"; exit 1; }
  echo "=== $f: signed by $FPR"
  files="$files $f"
done
# Only once every package verified
for f in $files; do cp "$tmp/$f" "$tmp/$f.sig" repo/ || exit 1; done
cd repo && repo-add -R zpt-artix.db.tar.zst $files
