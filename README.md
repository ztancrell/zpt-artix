# zpt-artix

My own Artix Linux (OpenRC) pacman repo: OpenRC scripts for services Artix has none for, and
Artix rebuilds of packages from [zpt-cachy](https://github.com/ztancrell/zpt-cachy). See
`../zartix/DESIGN.md` for the idea and decisions.

## What's here

- `pkgs/<name>/PKGBUILD`: one directory per package.
  - `ananicy-cpp`: auto nice daemon ([ananicy-cpp](https://gitlab.com/ananicy-cpp/ananicy-cpp),
    release 1.2.0), built without systemd (`-DENABLE_SYSTEMD=OFF`: no libsystemd link, no
    `.service` file), with the BPF process listener and regex rule support. Ships no rules: put them in
    `/etc/ananicy.d`.
  - `ananicy-cpp-openrc`: OpenRC script `/etc/init.d/ananicy-cpp` (`supervise-daemon`,
    `rc-service ananicy-cpp reload` reloads the rules).
  - `cachyos-ananicy-rules`: CachyOS's ananicy-cpp rules
    ([ananicy-rules](https://github.com/CachyOS/ananicy-rules), release 1.1.49) in `/etc/ananicy.d`.
    `ananicy.conf` is a backup file: if ananicy-cpp already generated one, the CachyOS one lands as
    `ananicy.conf.pacnew`.
  - `scx-scheds`: sched_ext schedulers and tools ([scx](https://github.com/sched-ext/scx),
    release 1.1.4), built like Arch's package. Needs a kernel with sched_ext.
  - `scx-tools`: `scx_loader` (D-Bus daemon that starts and switches schedulers), `scxctl`, `scxtui`
    ([scx-loader](https://github.com/sched-ext/scx-loader), release 1.1.3), without the systemd
    unit and D-Bus activation file. Config: `/etc/scx_loader.toml` (sample in `/usr/share/scx_loader/config.toml`). `scxtui`'s
    log view reads journalctl, so it shows nothing on Artix.
  - `scx-loader-openrc`: OpenRC script `/etc/init.d/scx_loader` (`supervise-daemon`, needs dbus,
    stops with SIGINT like the upstream unit), and the D-Bus activation file
    `org.scx.Loader.service`, which runs `rc-service scx_loader start`: the loader starts on demand,
    supervised by OpenRC. In no runlevel by default.
  - `systemd-boot-cachyos-signed-efi`: the CachyOS-signed systemd-boot EFI file
    `/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed`, taken byte-identical from CachyOS's
    `systemd-boot-cachyos-signed` 262.2_1-1 (package pinned by sha256, its signature checked against
    CachyOS's packager key in `prepare()`), never rebuilt. Without that package's systemd dependency
    and its pacman hook (which uses bootctl); `eac-tools` has an Artix hook in its place.
  - `eac-tools`: `eac-setup` and `eac-status` for Easy Anti-Cheat Linux v2, from
    [CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) 1.4.4 (tag tarball, sha512
    pinned), ported by `eac-artix.patch`: Limine only (with `limine-mkinitcpio-hook`; the
    systemd-boot and rEFInd paths are removed), `loginctl` (elogind) instead of `systemctl`, the EFI
    system partition found with findmnt/lsblk instead of `bootctl`, and it installs
    `systemd-boot-cachyos-signed-efi`. Needs `limine-mkinitcpio-hook` (galaxy) and elogind.
    `eac-sdboot.hook` runs `/usr/lib/eac-tools/eac-sdboot-update` after the signed EFI file is
    installed or upgraded: it recopies it to `<ESP>/EFI/cachyos-eac/systemd-bootx64.efi`, only if
    eac-setup already put a copy there.
    Setup steps: [CachyOS wiki](https://wiki.cachyos.org/configuration/easy_anti_cheat/).
  - `zpt-artix-settings`: CachyOS's system tuning from
    [CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) 1.4.4 (same tag tarball and
    sha512 pin as `eac-tools`), in place of CachyOS's `cachyos-settings` (conflicts with it). Needs
    `ananicy-cpp-openrc`, `cachyos-ananicy-rules`, `zramen-openrc`, elogind, iw, wireless-regdb and
    pciutils; optional: `lua-luv` (topmem), `power-profiles-daemon` (game-performance), hdparm
    (`69-hdparm.rules`).
    - Kept as-is: sysctl (`70-cachyos-settings.conf`), all udev rules and `audio-pm-ctl`, modprobe.d
      (amdgpu, blacklist, nvidia), `modules-load.d/ntsync.conf` (OpenRC's `modules` service reads
      `/usr/lib/modules-load.d`), tmpfiles.d (coredump, thp, thp-shrinker), `limits.d/20-audio.conf`,
      the X11 touchpad config, `iw-set-regdomain`, and the tools `pci-latency`, `zink-run`,
      `dlss-swapper`, `dlss-swapper-dll`, `topmem`, `kerver`.
    - Ported: `game-performance` uses `elogind-inhibit` instead of `systemd-inhibit`;
      `/etc/init.d/pci-latency` is a one-shot OpenRC script in place of `pci-latency.service`, in no
      runlevel by default (`rc-update add pci-latency default`); the user open file limit
      (systemd `DefaultLimitNOFILE=1024:1048576`) is `/etc/security/limits.d/30-nofile.conf`.
    - Left to Artix's defaults: zram and time servers. zramen has no config file (only environment
      variables, which would mean owning `/etc/conf.d/zramen`), and Artix's `chrony.conf` includes no
      drop-in directory, so zramen keeps its defaults (lz4, 25% of RAM, priority 32767) instead of
      CachyOS's zstd, size = RAM, priority 100, and chrony keeps `pool 2.arch.pool.ntp.org` instead of
      `time.cloudflare.com`.
    - Dropped: everything under `/usr/lib/systemd`, NetworkManager's `dns=systemd-resolved` (breaks
      DNS on Artix), CachyOS branding and services (`cachyos.svg`, the GNOME login-screen override,
      debuginfod URLs, `paste-cachyos`, `cachyos-bugreport.sh`, `sbctl-batch-sign`), and
      `eac-setup`/`eac-status` (in `eac-tools`).
    - Inert on Artix, kept as-is: `85-iw-regulatory.rules` starts a systemd unit, and
      `iw-set-regdomain` reads the timezone with `timedatectl`, so the regulatory domain is not set
      automatically; `kerver`'s scheduler section reads journalctl and shows nothing.
    - Keep-list rule: `package()` installs only files on `_keep` and fails the build on any upstream
      file on neither `_keep` nor `_drop`, naming it. To bump: set `pkgver` to the new tag, run
      `updpkgsums`, build, and sort every file the build names onto `_keep` or `_drop` (port it if it
      needs systemd). The build also fails if the `game-performance` port no longer applies. Bump
      `eac-tools` to the same tag.
- Mirrored, not built: `linux-cachyos-eac` (7.3.3-2) and `cachyos-eac-signing-key` (1-2) are
  CachyOS's signed packages, copied into `repo/` unchanged with their `.sig` by `mirror-cachyos.sh`.
  The kernel and the systemd-boot file must keep CachyOS's Secure Boot signature, so they are never
  rebuilt. Sources: kernel [linux-cachyos](https://github.com/CachyOS/linux-cachyos)
  (`linux-cachyos-eac`, GPL-2.0), systemd-boot [systemd](https://github.com/systemd/systemd) 262.2
  (LGPL-2.1+).
- `zpt-artix.asc`: this repo's public signing key (`zpt-artix repo`, ed25519, fingerprint
  `473D2CE689E0FE660D43FD715566DC3F8C6B2B75`). The private key exists only as the
  `GPG_PRIVATE_KEY` secret of the GitHub repo, for the planned CI signing; nothing is signed with
  it yet.
- `keys/cachyos.asc`: CachyOS's packager key (`CachyOS <admin@cachyos.org>`,
  fingerprint `882DCFE48E2051D48E2562ABF3B607488DB35A47`), byte-identical to
  `/usr/share/pacman/keyrings/cachyos.gpg` from CachyOS's `cachyos-keyring` 20240331-1. pacman checks
  the mirrored packages' `.sig` files, so add the key once on Artix (only the key, never the CachyOS
  repo): `sudo pacman-key --add keys/cachyos.asc && sudo pacman-key --lsign-key 882DCFE48E2051D48E2562ABF3B607488DB35A47`.
- `mirror-cachyos.sh`: downloads the packages pinned in its `PKGS` line and their `.sig` from a
  CachyOS mirror (x86_64 `cachyos` repo; `MIRROR` overrides it), verifies each signature with gpgv
  against `keys/cachyos.asc` by full fingerprint, refuses on any failure (nothing is copied), then
  copies the files unchanged into `repo/` and runs `repo-add`. No headers, NVIDIA, ZFS or r8125
  packages (module signatures are enforced in the EAC boot).
- `build.sh`: builds every package in `pkgs/` (or only the `pkgs/<dir>/` arguments) with `makepkg -f`
  (never installs anything), copies the results into `repo/` and indexes them with `repo-add` into
  `repo/zpt-artix.db.tar.zst`. `MAKEPKG_EXTRA` adds makepkg flags. It skips the dep check for
  `zpt-artix-*`, `*-dkms` and `*-openrc` directories (their dependencies live only in this repo,
  or are runtime-only).
- `container-build.sh`: runs `build.sh` in a fresh `docker.io/artixlinux/artixlinux:base-devel`
  container (rootless podman, `--rm`, this directory mounted), as a build user with your uid, with
  `MAKEPKG_EXTRA="-s --noconfirm"`, so build deps are installed in the container only and packages
  link against Artix libraries, not the host's.
- `repo/`: the built local repo (not committed).

## Build

```sh
./container-build.sh            # every package
./container-build.sh pkgs/ananicy-cpp/
```

Needs podman. Don't run `build.sh` directly on a non-Artix host.

New EAC kernel: look up the version CachyOS ships (`linux-cachyos-eac` in the `cachyos` repo, for
example at `https://cdn77.cachyos.org/repo/x86_64/cachyos/`), put it in the `PKGS` line of
`mirror-cachyos.sh`, run `./mirror-cachyos.sh` (needs curl, gpg and repo-add, on any host: it only
copies files) and commit the changed line. `repo-add -R` deletes the old package file from `repo/`;
delete its old `.sig` if it is left over.
