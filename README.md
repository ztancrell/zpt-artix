# zpt-artix

My own Artix Linux (OpenRC) pacman repo: OpenRC scripts for services Artix has none for, and
Artix rebuilds of packages from [zpt-cachy](https://github.com/ztancrell/zpt-cachy). See
`../zartix/DESIGN.md` for the idea and decisions.

## What's here

- `pkgs/<name>/PKGBUILD`: one directory per package.
  - `ananicy-cpp`: auto nice daemon ([ananicy-cpp](https://gitlab.com/ananicy-cpp/ananicy-cpp),
    release 1.2.0), built without systemd (`-DENABLE_SYSTEMD=OFF`: no libsystemd link, no
    `.service` file), with the BPF process listener and regex rule support. Ships no rules: put them in
    `/etc/ananicy.d`. `singleton-flock.patch`: upstream's "already running" check creates
    `/dev/shm/AnanicyCppMutex` exclusively and deletes it only on a clean exit, so after a `kill -9`
    or crash every start failed with `Ananicy Cpp is already running!` until reboot. The patch holds
    a `flock` on that file instead, which the kernel drops when the process dies.
  - `ananicy-cpp-openrc`: OpenRC script `/etc/init.d/ananicy-cpp` (`supervise-daemon`,
    `rc-service ananicy-cpp reload` reloads the rules). The daemon's stdout and stderr go to
    `/var/log/ananicy-cpp.log`.
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
  - `dmemcg-booster`: Valve's dmem cgroup daemon
    ([dmemcg-booster](https://gitlab.steamos.cloud/holo/dmemcg-booster), 0.1.3, commit `4305d74`,
    MIT), without the systemd units. It sets `dmem.low` (protected GPU memory) to the full
    `dmem.capacity` on cgroups, enabling the dmem controller in `cgroup.subtree_control` where needed,
    and leaves users' own cgroups below `user-<id>.slice` alone. Every cgroup gets the same
    protection: it does not detect games yet. `rescan-no-dbus.patch`: upstream finds new cgroups
    through systemd's `UnitNew` D-Bus signal, which Artix never sends, so the patch rescans the whole
    cgroup tree every 10 seconds instead (same walk as upstream's startup pass, cgroup-writing code
    unchanged) and drops the D-Bus code and the `dbus` crate: links only glibc and libgcc.
  - `dmemcg-booster-openrc`: OpenRC script `/etc/init.d/dmemcg-booster` (`supervise-daemon`, the
    system instance, needs `cgroups`). Output to `/var/log/dmemcg-booster.log`. In no runlevel by
    default: `rc-update add dmemcg-booster default`.
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
  - The homestead X stack, from the owner's forks (each pinned to a commit, pkgver from git), moved
    from zpt-cachy and built with Artix's default generic x86-64 flags:
    - `xlibre-xserver-homestead`: the XLibre X server ([xserver](https://github.com/ztancrell/xserver)),
      one package with the common files and SDK (provides `xlibre-xserver`, `xorg-server` and their
      `-common`/`-devel`); no Xephyr, Xvfb, Xnest or suid wrapper. Without systemd: needs Artix's
      `libudev` instead of `systemd-libs`, and its logind support (`-D systemd_logind=true`, as in
      Artix's own `xlibre-xserver`) talks to elogind over D-Bus. Links no libsystemd.
    - `xlibre-input-libinput-homestead`: the libinput input driver
      ([xf86-input-libinput](https://github.com/ztancrell/xf86-input-libinput)). Builds against
      `xlibre-xserver-homestead`'s SDK (see `build.sh` below).
    - `openbox-homestead`: Openbox ([openbox-patchwork](https://github.com/ztancrell/openbox-patchwork)),
      `--enable-debug`, without the GNOME/KDE session files.
    - `fastcompmgr-homestead`: the X11 compositor ([fastcompmgr](https://github.com/ztancrell/fastcompmgr)).
    - `tint2-homestead`: the panel ([tint2](https://github.com/ztancrell/tint2)), without `tint2conf`.
  - Desktop tools in no Artix repo, built from Arch's or the AUR's PKGBUILD (named in each one's
    first line), unchanged unless noted:
    - `wmctrl` 1.07 (Arch): tarball from Debian's archive, same sha512 (web.archive.org serves
      Arch's URL decompressed).
    - `dex` 0.10.1 (Arch).
    - `obmenu-generator` 0.93 (AUR); its `openbox` dependency is met by `openbox-homestead`.
    - `perl-linux-desktopfiles` 0.26 (AUR), needed by `obmenu-generator`.
    - `xcursor-neutral` 1.13a (AUR): source from the mirror its PKGBUILD names, same sha256
      (distribute.kde.org no longer serves it).
  - `zpt-artix-desktop`: meta-package (no files) for the whole desktop: the homestead X stack,
    xinit/xrandr/xset, xclip, xdotool, wmctrl, `ly` + `ly-openrc`, session tools (obmenu-generator,
    dex, dunst, feh,
    polkit-gnome, lxappearance-obconf, xdg-user-dirs-gtk, xdg-desktop-portal-gtk, slock, redshift,
    flameshot, scrot), Thunar with its plugins, tumbler, gvfs and archivers, PipeWire with
    `pipewire-openrc`/`pipewire-pulse-openrc`/`wireplumber-openrc`, pavucontrol, pasystray,
    `networkmanager-openrc`, network-manager-applet, nss-mdns, `bluez-openrc`, blueman, kitty,
    fonts, the xcursor-neutral cursor theme, upower and `power-profiles-daemon-openrc`. No GPU
    drivers or microcode (per machine).
  - Apps in no Artix repo that need Electron 43 (Artix's newest is electron42), so they ship as
    upstream's prebuilt binaries with their own bundled Electron, from the AUR's `-bin` PKGBUILD
    (named in each one's first line), unchanged:
    - `obsidian-bin` 1.8.10 (AUR; upstream's `.deb`, in `/opt/Obsidian`; proprietary licence). The
      AUR pins 1.8.10, older than Arch's obsidian 1.15.1 (which needs electron43).
    - `heroic-games-launcher-bin` 2.22.4 (AUR; upstream's `Heroic-2.22.4-linux-x64.pacman`, in
      `/opt/Heroic`).
  - `zpt-artix-apps`: meta-package for everyday apps: firefox, thunderbird, `obsidian-bin`,
    qbittorrent, audacious, steam, lutris, `heroic-games-launcher-bin`, mangohud, gamemode,
    gamescope, protontricks, git, github-cli, htop, fastfetch, ripgrep, flatpak. `steam` is in
    Artix's `[lib32]` repo, which Artix's default `pacman.conf` leaves off: enable it first.
- Mirrored, not built: `linux-cachyos-eac` (7.3.3-2) and `cachyos-eac-signing-key` (1-2) are
  CachyOS's signed packages, copied into `repo/` unchanged with their `.sig` by `mirror-cachyos.sh`.
  CI then deletes CachyOS's `.sig` and signs them with the zpt-artix key, like every other package.
  The kernel and the systemd-boot file must keep CachyOS's Secure Boot signature, so they are never
  rebuilt. Sources: kernel [linux-cachyos](https://github.com/CachyOS/linux-cachyos)
  (`linux-cachyos-eac`, GPL-2.0), systemd-boot [systemd](https://github.com/systemd/systemd) 262.2
  (LGPL-2.1+).
- `zpt-artix.asc`: this repo's public signing key (`zpt-artix repo`, ed25519, fingerprint
  `473D2CE689E0FE660D43FD715566DC3F8C6B2B75`). The private key exists only as the
  `GPG_PRIVATE_KEY` secret of the GitHub repo, its passphrase as `GPG_PASSPHRASE`; CI signs
  every package and the db with it.
- `keys/cachyos.asc`: CachyOS's packager key (`CachyOS <admin@cachyos.org>`,
  fingerprint `882DCFE48E2051D48E2562ABF3B607488DB35A47`), byte-identical to
  `/usr/share/pacman/keyrings/cachyos.gpg` from CachyOS's `cachyos-keyring` 20240331-1. Only
  `mirror-cachyos.sh` uses it; pacman never needs it to install from the published repo (CI re-signs
  the mirrored packages with the zpt-artix key).
- `mirror-cachyos.sh`: downloads the packages pinned in its `PKGS` line and their `.sig` from a
  CachyOS mirror (x86_64 `cachyos` repo; `MIRROR` overrides it), verifies each signature with gpgv
  against `keys/cachyos.asc` by full fingerprint, refuses on any failure (nothing is copied), then
  copies the files unchanged into `repo/` and runs `repo-add`. No headers, NVIDIA, ZFS or r8125
  packages (module signatures are enforced in the EAC boot).
- `build.sh`: builds every package in `pkgs/` (or only the `pkgs/<dir>/` arguments) with `makepkg -f`
  (never installs anything), copies the results into `repo/` and indexes them with `repo-add` into
  `repo/zpt-artix.db.tar.zst`. `MAKEPKG_EXTRA` adds makepkg flags. It skips the dep check for
  `zpt-artix-*`, `*-dkms` and `*-openrc` directories (their dependencies live only in this repo,
  or are runtime-only). If `pacman.conf` has `repo/` as a `file://` `[zpt-artix]` repo
  (`container-build.sh` and CI add it), it then indexes what was built and retries the failed
  packages (again, as long as each round builds something), so a package that builds against another one of this repo
  (`xlibre-input-libinput-homestead` needs `xlibre-xserver-homestead`) gets it from `repo/`.
- `container-build.sh`: runs `build.sh` in a fresh `docker.io/artixlinux/artixlinux:base-devel`
  container (rootless podman, `--rm`, this directory mounted), as a build user with your uid, with
  `MAKEPKG_EXTRA="-s --noconfirm"`, so build deps are installed in the container only and packages
  link against Artix libraries, not the host's. It adds `repo/` to the container's `pacman.conf`
  as the local `[zpt-artix]` repo (unsigned, container only).
- `test-openrc.sh`: checks an installed OpenRC service, see [Test an OpenRC service](#test-an-openrc-service).
- `repo/`: the built local repo (not committed).
- `.github/workflows/repo.yml`: CI, see [CI](#ci).

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

## Test an OpenRC service

On the Artix machine, with the package installed:

```sh
sudo ./test-openrc.sh ananicy-cpp
```

It reads `command`, `supervisor`, `pidfile` and `extra_started_commands`/`extra_commands` from
`/etc/init.d/<service>` and checks: start (status started, daemon process running), stop (status
stopped, no daemon left), with `supervisor=supervise-daemon` that a `kill -9` of the daemon is
respawned with a new PID that is still alive 2 seconds later, and if the script has a `reload`
command that it exits 0 and the daemon keeps running. It prints one PASS/FAIL line per step, exits
non-zero if any failed, and leaves the service started or stopped as it found it (started also
means the daemon process is running). The boot check stays manual:
`rc-update add <service> default`, reboot, `rc-status`.

## CI

`.github/workflows/repo.yml` runs on every push to `master`, weekly (Monday 04:17 UTC) and by hand
(Actions tab, "Run workflow", or `gh workflow run repo`). In a fresh
`docker.io/artixlinux/artixlinux:base-devel` container it:

1. builds every package with `build.sh` as a non-root build user, with
   `MAKEPKG_EXTRA="-s --noconfirm -c"` (build deps come from the Artix repos; `-c` deletes each
   package's `src/` and `pkg/` after it builds, to stay within the runner's disk). No build order is
   needed: `build.sh` skips the dep check for `*-openrc` and `zpt-artix-*`, `scx-tools` adds
   `scx-scheds` only at package time, and `build.sh` retries `xlibre-input-libinput-homestead`
   against `repo/` (added to the container's `pacman.conf` as the local `[zpt-artix]` repo) after
   `xlibre-xserver-homestead` has built, and `obmenu-generator` after `perl-linux-desktopfiles`;
2. runs `mirror-cachyos.sh` (it fails the run unless every CachyOS signature verifies), then deletes
   CachyOS's `.sig` files;
3. runs `namcap` on every package: report only, in the run's summary page (namcap's errors include
   false positives, so they don't fail the run);
4. signs every package and the db with the zpt-artix key (private key in the `GPG_PRIVATE_KEY`
   secret, its passphrase in `GPG_PASSPHRASE`); `repo-add --verify` checks every package signature;
5. only if all of that passed: updates the rolling release [`repo`](https://github.com/ztancrell/zpt-artix/releases/tag/repo)
   in place, so it always mirrors the current repo and is never missing: new packages and `.sig` files
   first, then `zpt-artix.db`/`.files` (+ `.sig`), then it deletes assets no longer in the repo.
   Scheduled runs stop before this step: they never publish.

Results: <https://github.com/ztancrell/zpt-artix/actions>. Signing key `zpt-artix.asc`, fingerprint
`473D2CE689E0FE660D43FD715566DC3F8C6B2B75`.

## Install

Once on each Artix machine, trust the repo key (only this key: the CachyOS key is not needed):

```sh
curl -sLO https://raw.githubusercontent.com/ztancrell/zpt-artix/master/zpt-artix.asc
sudo pacman-key --add zpt-artix.asc
sudo pacman-key --lsign-key 473D2CE689E0FE660D43FD715566DC3F8C6B2B75
```

Add to `/etc/pacman.conf`, after the Artix repos (default `SigLevel`, signatures required):

```ini
[zpt-artix]
Server = https://github.com/ztancrell/zpt-artix/releases/download/repo
```

## Desktop

With the repo added (above), install the meta-packages. `zpt-artix-apps` needs Artix's `[lib32]`
repo for `steam`: uncomment it in `/etc/pacman.conf` (or add `[lib32]` with
`Include = /etc/pacman.d/mirrorlist`), then `sudo pacman -Sy`.

```sh
sudo pacman -S zpt-artix-desktop zpt-artix-apps
sudo rc-update add ly default             # login: ly on tty7 (or the tty set in /etc/ly/config.ini)
sudo rc-update add NetworkManager default
sudo rc-update add bluetoothd default
sudo rc-update add power-profiles-daemon default
```

`ly-openrc`'s service is `ly` (`/etc/init.d/ly`, supervise-daemon runs `/usr/bin/ly-dm` through
getty/agetty, `provide display-manager`); it conflicts with Artix's other display manager scripts
(`init-displaymanager`). PipeWire, pipewire-pulse and WirePlumber are OpenRC user services
(`/etc/user/init.d/`), not system services; how to enable them is not documented here yet. Not yet tested on a running system: the ly login
into the Openbox session and the user services.
