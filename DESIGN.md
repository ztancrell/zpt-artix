# zartix

## Idea

Artix Linux with CachyOS's gaming improvements and optimization patches: OpenRC, Openbox and
XLibre, no systemd, every service started by a script the owner controls. Packages and init scripts ship from
the owner's own pacman repo. The system is delivered as a custom Artix ISO with everything
already set up, installed fresh (not an in-place conversion of CachyOS).

## Open questions

- How `/home` carries over to the fresh install, and the way back if the first boot fails.
  Test plan so far: libvirt VM first, then real hardware.
- How to measure whether a CachyOS layer helps games (e.g. frametimes before/after).
- Disk is 97% full (18G free on a 473G btrfs `/`, 2026-11-19). Free space before any switch.
- Which layer-3 services are must-haves: Mullvad, scx schedulers, snapshot boot entries
  (limine-snapper-sync), LACT? Do the CachyOS tweaks (`cachyos-*`) go?
- Mullvad DNS without `systemd-resolved`: how it coexists with `dns-tls-relay` and
  NetworkManager. Needs a DNS leak test, not just a start check.
- Libre kernel and no non-free firmware too, or only systemd-free?

## Systemd inventory (CachyOS, 2026-11-19)

Verified against the Artix repo databases on mirrors.dotsrc.org, 2026-11-19
(system, world, galaxy, lib32; testing repos for xlibre/scx/bpftune/ananicy-cpp).

1. Core, swapped by Artix as a block: `openrc` (+ `openrc-init` as PID 1 via `base`),
   `elogind` + `elogind-openrc`, `libudev`/`udev` (built from systemd sources, no eudev),
   `libelogind`, `esysusers`/`etmpfiles`. Replacements: `openresolv` (resolved), `chrony`
   (timesyncd), `earlyoom` (oomd), `cronie` (timers), `dbus-openrc`. All exist with `-openrc`.
2. Artix ships `-openrc` packages for: networkmanager, bluez, avahi, openssh, libvirt (virtlogd
   and virtlockd scripts unverified), ufw, lact, mullvad (`mullvad-vpn-openrc`, galaxy),
   limine-snapper-sync, power-profiles-daemon, zram (`zramen-openrc`), and pipewire /
   pipewire-pulse / wireplumber (OpenRC user services).
3. No Artix package, custom `zpt-artix` work: ananicy-cpp + CachyOS rules and scx-scheds +
   scx-tools, dmemcg-booster (all packaged with `-openrc` scripts, 2026-11-19), bpftune,
   dns-tls-relay. acsandboxd dropped (see Decided). Snapper timers and other timers become cron jobs.
4. Exist with no `-openrc` (likely D-Bus or initramfs started, untested): udisks2, polkit,
   plymouth, profile-sync-daemon.
5. User layer to Openbox autostart or cron: psd, xdg-user-dirs, p11-kit-server;
   homestead-tint2-header.path (inotify loop); timers arch-update, dotfiles-backup,
   protonplus, threatfeed, fstrim, snapper-cleanup, plocate, man-db, logrotate, tmpfiles-clean.

XLibre: no binary package in any Artix repo. Package sources exist on gitea.artixlinux.org
(`packages/xlibre-xserver`, `xlibre-video-*`, `xlibre-input-*`), and `iso-profiles` has a
`use-xlibre` switch whose package list uses different names (`xlibre-xf86-video-*`). So XLibre
gets built into `zpt-artix`. Openbox, limine, mkinitcpio and `artools` (world) all exist.

From zpt-cachy, only `xlibre-xserver-homestead` links to systemd-libs. No display manager
is in use (X started directly).

Checked in the Artix base-devel container, 2026-11-19 (built in `zpt-artix`):
- `xlibre-xserver-homestead` builds on Artix with `libudev` in place of `systemd-libs` and
  `-D systemd_logind=true` (as Artix's own `xlibre-xserver` 25.1.9 on gitea): meson finds no
  libsystemd, and no ELF file in the five homestead packages links libsystemd (Xorg links
  `libudev.so.1`). Not yet run on a real Artix session.
- Not in Artix's system, world, galaxy or lib32 repos (checked 2026-11-19): wmctrl,
  obmenu-generator, dex, xcursor-neutral, obsidian, heroic-games-launcher.
  - wmctrl, dex (Arch), obmenu-generator, xcursor-neutral and obmenu-generator's dependency
    perl-linux-desktopfiles (AUR) are packaged in zpt-artix and back in `zpt-artix-desktop`.
  - obsidian and heroic-games-launcher: Arch's obsidian 1.15.1 and AUR heroic-games-launcher
    2.22.4 both need electron43, and Artix's newest is electron42. Packaged in zpt-artix as
    `obsidian-bin` 1.15.1 (AUR obsidian-bin, which pins 1.8.10, bumped to Arch's 1.15.1 tarball and
    checksum) and `heroic-games-launcher-bin` (AUR 2.22.4-1) and in
    `zpt-artix-apps` (see Decided, 2026-11-19).
- `steam` is in lib32, which the base-devel image's `pacman.conf` does not enable
  (system, world, galaxy only).
- `ly-openrc` 20240824-2 ships `/etc/init.d/ly` (service `ly`, runs `/usr/bin/ly-dm`, which
  `ly` 1.4.1 ships). PipeWire, pipewire-pulse and WirePlumber `-openrc` are OpenRC user
  services in `/etc/user/init.d/`.

## Decided

- 2026-11-19: Services without an Artix init script get custom OpenRC scripts.
- 2026-11-19: New pacman repo `zpt-artix` holds the OpenRC script packages (`<name>-openrc`,
  matching Artix's pattern) and the Artix rebuilds of zpt-cachy packages. `zpt-cachy` stays
  frozen as the fallback until Artix boots well, then retires.
- 2026-11-19: Build a custom Artix ISO (with `artools`) that has the full setup preinstalled:
  OpenRC, Openbox, XLibre, the `zpt-artix` repo and its packages. Fresh install, not in-place
  conversion. Superseded: the earlier open question "in-place or fresh install".
- 2026-11-19: No older packages unless absolutely needed. ananicy-cpp is packaged in
  `zpt-artix` (not Artix's older `ananicy`).
- 2026-11-19: A rootless podman container running Artix builds every `zpt-artix` package from
  scratch. A libvirt VM boots the ISO and tests services (a container can't test OpenRC boot).
- 2026-11-19: `zpt-artix` is hosted like `zpt-cachy`: a GitHub repo with the package database
  in a release.
- 2026-11-19: CachyOS layers to bring over, all must-have: 1. kernel (`linux-cachyos`
  patches), 2. schedulers (scx, ananicy-cpp + rules), 3. system tuning (`cachyos-settings`
  ported to OpenRC), 4. gaming packages (`proton-cachyos`, `wine-cachyos` and similar).
  Not now: 5. whole-system x86-64-v3 rebuilds (thousands of packages, smallest gaming gain).
- 2026-11-19: scx_loader starts on demand through D-Bus activation, handed to OpenRC: the
  activation file runs `rc-service scx_loader start`, so OpenRC supervises the only copy. Not
  in any runlevel by default. Unverified that dbus-daemon accepts an Exec that exits after
  handing off; test in the VM. Fallback: drop the activation file, OpenRC only.
- 2026-11-19: EAC v2 (Easy Anti-Cheat Linux v2) on Artix from CachyOS's signed binaries, never
  rebuilt: `zpt-artix` mirrors `linux-cachyos-eac` and `cachyos-eac-signing-key` unchanged,
  repackages the CachyOS-signed systemd-boot EFI byte-for-byte without its systemd dependency
  (checksum-proven), and ports `eac-setup`/`eac-status` off systemctl/bootctl. The CachyOS repo
  is never added on Artix. Unknown until a real EAC v2 game test: whether EAC v2 accepts this
  on Artix user space. EAC v1 (Proton's runtime) needs nothing.
- 2026-11-19: ac-sandbox (acsandboxd) is not packaged for Artix; EAC v2 covers what it
  explored. The project stays in ~/projects/ac-sandbox.
- 2026-11-19: CachyOS system tuning ships as one package, `zpt-artix-settings`, built from
  CachyOS's upstream settings source at a pinned tag and bumped to pull future tweaks. Kept:
  sysctl, udev rules, modprobe/modules-load, tmpfiles, limits, touchpad, gaming tools; ported:
  game-performance (elogind-inhibit), pci-latency (OpenRC one-shot), user file limits
  (/etc/security/limits.d). zram and time servers stay at zramen's and chrony's defaults: neither
  has a drop-in config (built 2026-11-19). Inert on Artix: the WiFi regdomain udev rule
  (starts a systemd unit, helper uses timedatectl) and kerver's journalctl section. Dropped: systemd-only tweaks, CachyOS branding and
  services, NetworkManager `dns=systemd-resolved`. eac-setup/eac-status live in `eac-tools`.
  An explicit keep-list makes any new upstream file fail the build until reviewed.
- 2026-11-19: Pacman on Artix trusts only the owner's key. Mirrored CachyOS packages are
  verified against CachyOS's key, their CachyOS signatures discarded, and every package plus
  the db re-signed with a new `zpt-artix` key in `zpt-artix` CI (as zpt-cachy CI does). The
  owner creates the key; the private key lives only as a GitHub secret. Until CI exists, the
  local repo/ keeps CachyOS's .sig files (nothing installs from it yet).
- 2026-11-19: An Artix pacman hook in `eac-tools` recopies the signed systemd-boot EFI to
  `$ESP/EFI/cachyos-eac/` after upgrades, only if eac-setup already put it there. No bootctl.
- 2026-11-19: zram stays the owner's current local setup, not packaged: 1.5x RAM, zstd,
  priority 100 (today `/etc/systemd/zram-generator.conf`, `zram-size = ram * 1.5`). On Artix:
  `/etc/conf.d/zramen` with `export ZRAM_SIZE=150`, `export ZRAM_COMP_ALGORITHM=zstd`,
  `export ZRAM_PRIORITY=100` (no package ships that file; zramen has no size cap unless
  `ZRAM_MAX_SIZE` is set). The ISO step puts it in place.
- 2026-11-19: The MacBookPro16,1 (2019, T2) moves to Artix too, replacing macOS once macOS
  drops support for it. zpt-cachy's T2 packages then need Artix rebuilds and OpenRC scripts for
  their systemd units. Not before that. Superseded: the open question "Does the MacBookPro16,1
  move to Artix too, or only the desktop?"
- 2026-11-19: Own packages in `zpt-artix` build generic x86-64 (Artix's default flags), so they
  run on any x86-64 machine. No x86-64-v3 flags, unlike zpt-cachy.
- 2026-11-19: zpt-cachy's `zpt-cachy-desktop` becomes `zpt-artix-desktop`: a meta-package that
  pulls in everything that makes the owner's desktop usable (the homestead X stack plus the
  session packages). Agreed contents: homestead X stack, ly, session tools (dunst, feh,
  polkit-gnome, obmenu-generator, ...), Thunar, PipeWire, NetworkManager, Bluetooth, kitty,
  fonts, power tools. Left out: per-machine GPU drivers and microcode, CachyOS-only packages,
  duplicate network managers (iwd, netctl).
- 2026-11-19: Everyday apps get a second meta-package, `zpt-artix-apps`.
- 2026-11-19: Login with `ly` (Artix world: `ly` + `ly-openrc`).
- 2026-11-19: dmemcg-booster is ported, first as it behaves on CachyOS: same equal `dmem.low`
  for every cgroup, with the systemd D-Bus signal loop replaced by a periodic rescan, plus an
  OpenRC script. Later: make it actually protect the foreground game (game in its own cgroup).
  Facts (source tag 0.1.3): no libsystemd use, no game detection; its user instance's writes
  fail even on CachyOS; Artix's kernel has CONFIG_CGROUP_DMEM=y. Superseded: the open question
  "`dmemcg-booster` depends on systemd cgroup slices: drop, or rebuild from scratch?"
- 2026-11-19: obsidian and heroic-games-launcher ship in `zpt-artix` as upstream's prebuilt
  binaries with their bundled Electron (`obsidian-bin`, `heroic-games-launcher-bin`), since both
  need Electron 43 and Artix stops at 42. Both go in `zpt-artix-apps`.
- 2026-11-19: The desktop's Homestead theming is the system default on every zpt-artix machine
  (Openbox/GTK theme, icons, cursor, tint2, kitty, Openbox menu), shipped as system defaults
  (`/etc/xdg`, `/usr/share`) so `~/.config` still overrides them. Per-machine theming comes later.
  The theme files live in the homestead repo. The KDE-classic cursor ships too (with Neutral),
  its source and licence still unknown. All of `~/.wallpapers` (300M) ships in the public repo,
  the owner's choice knowing most of it is other artists' work.
- 2026-11-19: Retina machines (first the 2014 MacBook Pro, 2560x1600 at ~224 DPI) keep the full
  native resolution and scale each piece 2x (fonts via Xft.dpi, GTK, Qt, cursor, tint2). The
  settings live in a small per-machine package installed only there; the desktop stays unchanged.
- 2026-11-19: Install from Artix's plain base ISO (no desktop, so nothing to purge) with an own
  install script in the spirit of archinstall, which then installs from zpt-artix. Superseded: the
  open question "Installer on the ISO: Calamares (GUI), an own script, or live-only first?".
- 2026-11-23: The T2 packages are ported now, not when macOS drops the MacBookPro16,1:
  `t2-dkms`, `t2-support`, `t2-apps` and `bankstown-lv2` from zpt-cachy, with OpenRC scripts for
  their system daemons, elogind's system-sleep folder for the sleep hooks, OpenRC user services for
  the sidecar, and `zpt-artix-mac` as the meta-package. Superseded (same day): the sidecar is
  dropped; see the next entry. Superseded: "Not before that" in the
  MacBookPro16,1 entry above. The 2019 Mac is now a zpt-artix target alongside the 2014 Mac.
- 2026-11-23: These notes moved from `../zartix/DESIGN.md` (gone from disk; restored from the
  2026-11-19 home backup) into this repo. The GitHub repo `ztancrell/zpt-cachy` was deleted on
  2026-11-23; its last clone is in that backup.
- 2026-11-23: T2 port details, after finding upstream calls systemd tools at runtime:
  - Dropped: `t2-journal` (needs journald) and `t2-sidecar` (all `systemctl --user`, needs
    GNOME's Mutter and Sunshine; the owner runs Openbox).
  - Patched to OpenRC (patches carried in this repo): the fan-control autostart switch,
    airshare's visibility switch and power-tune's persist use rc-update/rc-service; Touch Bar
    `run=` keys run their command directly instead of through `systemd-run --user`.
  - Added: an OpenRC fprintd service with the Touch ID bridge's settings; D-Bus Exec= rewritten to
    the real binaries for t2-drop and airshare; an elogind sleep hook that re-attaches the Touch Bar
    after resume.
  - The 2019 Mac runs Artix's `linux` with `linux-headers` for the T2 DKMS modules. The EAC kernel
    stays on the desktop; its headers are not mirrored.
