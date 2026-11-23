# zpt-artix

My own Artix Linux (OpenRC) pacman repo: OpenRC scripts for services Artix has none for, and
Artix rebuilds of packages from zpt-cachy (the owner's CachyOS repo; its GitHub repo was deleted
on 2026-11-23). See `DESIGN.md` for the idea and decisions.

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
  - `bpftune-openrc`: OpenRC script `/etc/init.d/bpftune` (`supervise-daemon`, respawns up to 5
    times like the upstream unit's `Restart=on-failure`, needs `localmount`, starts after `sysctl`
    and `net`). Needs `bpftune`, which is AUR only (`bpftune-git` provides it). In no runlevel by
    default: `rc-update add bpftune default`.
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
  - `zpt-artix-gaming`: the useful settings of Artix's beta gaming ISO profiles
    ([iso-profiles](https://gitea.artixlinux.org/artix/iso-profiles) `wip` branch, commit
    `14c737deee84a4406dd7313fba263618dbdf1f37`, `gaming-plasma/` and `gaming-xfce/`), BSD-2-Clause.
    Needs openrc; optional: timidity++, soundfont-generaluser and pipewire-jack (MIDI, below).
    - `/usr/lib/sysctl.d/80-gameperf.conf`: `vm.max_map_count = 2147483642`. It sorts after Artix's
      `10-artix.conf` (1048576), so it wins; `70-cachyos-settings.conf` doesn't set it.
    - `/etc/security/limits.d/0-gaming.conf`: memlock unlimited (soft and hard) for the `games`
      group. The ISO's `nofile 524288` for `@games` is left out: pam_limits applies a group entry over
      a `*` entry whatever the file order, so it would lower `30-nofile.conf`'s hard limit 1048576 for
      the group.
    - The games group: on install, the first user with UID 1000 is added to `games`, like the ISO's
      `local.d/0-gaming.start`. It prints what it did, does nothing if there is no such user, and
      never fails the install. Log in again for it to apply. Others: `sudo usermod -a -G games
      <user>`. Removing the package leaves group membership as it is.
    - MIDI for DOSBox-era games: `/usr/lib/modules-load.d/snd_virmidi.conf` (virtual MIDI ports,
      loaded by OpenRC's `modules` service at boot), and `/etc/user/init.d/timidity`, an OpenRC user
      service like PipeWire's (see [Desktop](#desktop)) in place of the ISO's dinit user service:
      supervise-daemon runs `timidity -c /etc/timidity/zpt-artix-gaming.cfg -iA -Oj` (ALSA sequencer
      in, JACK out) after `pipewire-pulse`. `zpt-artix-gaming.cfg` holds the ISO's one soundfont line,
      `/usr/share/soundfonts/GeneralUser.sf2` (timidity++ owns `/etc/timidity/timidity.cfg`). Setup:
      add Arch `[extra]` (see [Arch repos](#arch-repos)), then `sudo pacman -S timidity++
      pipewire-jack`, install `soundfont-generaluser` from the AUR with an AUR helper (this repo
      doesn't build it), and `rc-update --user add timidity default` (or `rc-service --user timidity
      start` once). In no runlevel by default.
    - Not ported: `vm.swappiness=10` (fights zram; `zpt-artix-settings` uses 100),
      `min_free_kbytes` 1 GB and the other vm and `kernel.sched_*` writes in the ISO's tmpfiles file
      (CachyOS's tuning leaves them at kernel defaults), its THP knobs (`zpt-artix-settings` ships
      CachyOS's `thp.conf`), its debugfs sched knobs (EEVDF slice tuning, no effect under scx), the
      PulseAudio `daemon.conf` (PipeWire is used), `linux-zen` (the CachyOS EAC kernel is used), and
      the demo games, desktop, lightdm, wallpaper and skel files.
  - The homestead X stack, from the owner's forks (each pinned to a commit, pkgver from git), moved
    from zpt-cachy and built with Artix's default generic x86-64 flags:
    - `xlibre-xserver-homestead`: the XLibre X server ([xserver](https://github.com/ztancrell/xserver)),
      one package with the common files and SDK (provides `xlibre-xserver`, `xorg-server` and their
      `-common`/`-devel`, and `x11win-server`, the X server name Artix's `sddm` depends on); no
      Xephyr, Xvfb, Xnest or suid wrapper. Without systemd: needs Artix's
      `libudev` instead of `systemd-libs`, and its logind support (`-D systemd_logind=true`, as in
      Artix's own `xlibre-xserver`) talks to elogind over D-Bus. Links no libsystemd.
    - `xlibre-input-libinput-homestead`: the libinput input driver
      ([xf86-input-libinput](https://github.com/ztancrell/xf86-input-libinput)). Builds against
      `xlibre-xserver-homestead`'s SDK (see `build.sh` below).
    - `openbox-homestead`: Openbox ([openbox-patchwork](https://github.com/ztancrell/openbox-patchwork)),
      `--enable-debug`, without the GNOME/KDE session files and without `/etc/xdg/openbox` (from
      `homestead-theme`).
    - `fastcompmgr-homestead`: the X11 compositor ([fastcompmgr](https://github.com/ztancrell/fastcompmgr)).
    - `tint2-homestead`: the panel ([tint2](https://github.com/ztancrell/tint2)), without `tint2conf`
      and without `/etc/xdg/tint2/tint2rc` (from `homestead-theme`).
  - The Homestead look, from [homestead](https://github.com/ztancrell/homestead)'s `theme/` and
    `wallpapers/` (pinned to a commit like the X stack). Homestead is the default look for every
    user; a user's own files in `~/.config` override it:
    - `homestead-theme`: the Homestead GTK 3/4 and Openbox theme (`/usr/share/themes/Homestead`),
      the `Homestead` icon theme (Breeze Dark) and `Homestead-Cursor` (the `KDE-classic` cursors, then
      Neutral), all in `/usr/share/icons`; GTK settings in `/etc/gtk-3.0` and `/etc/gtk-4.0`; and the
      defaults in `/etc/xdg`: `openbox/` (rc.xml, menu.xml, autostart, environment), `tint2/tint2rc`,
      `kitty/` (kitty.conf, homestead.conf), `obmenu-generator/` (config.pl, schema.pl) and
      `fastfetch/config.jsonc` (minimal, Artix logo), with
      sounds and scripts in `/usr/share/homestead`. The volume, screen brightness and keyboard
      backlight keys (XF86AudioRaiseVolume/LowerVolume/Mute, XF86MonBrightnessUp/Down,
      XF86KbdBrightnessUp/Down) run `/usr/share/homestead/scripts/homestead-osd`: amixer Master in 5%
      steps with the click sound, brightnessctl on the backlight (5%, never below 1%) or the
      `*kbd_backlight` LED (1/16 steps), then a short dunst popup with a level bar (notify-send; one
      popup per kind, replaced on each press). Without a backlight device the brightness keys do nothing.
      homestead-theme depends on brightnessctl and libnotify for this. brightnessctl's udev rule gives
      `/sys/class/backlight/*/brightness` to the `video` group and `/sys/class/leds/*/brightness` to
      `input`, so the keyboard backlight keys need the user in `input`
      (`sudo usermod -aG input <user>`, then log in again); otherwise they do nothing.
      The media keys (XF86AudioPlay/Next/Prev/Stop) run `playerctl`, so they control any MPRIS
      player (mpv through mpv-mpris), and W-m opens an empty mpv window to drop files on. Superseded
      since homestead-theme r30: they ran audacious, which it no longer depends on.
      These are the owner's configs without his monitor
      layout, Synergy or redshift script, with `loginctl suspend`. Artix's `default-cursors` owns
      `/usr/share/icons/default`, so the cursor comes from `XCURSOR_THEME` in
      `/etc/xdg/openbox/environment` (with `XCURSOR_SIZE` 24 unless already set) and the GTK settings. Override rules: `~/.config/openbox/rc.xml`
      and `menu.xml` replace the system ones, but `~/.config/openbox/autostart` runs after the system
      autostart, not instead of it; the autostart starts tint2 with `$HOMESTEAD_TINT2RC` if set, else
      `/etc/xdg/tint2/tint2rc`, and on
      first login copies `/etc/xdg/obmenu-generator` to `~/.config/obmenu-generator` (obmenu-generator
      reads only that and would otherwise write xterm defaults); `~/.config/gtk-3.0/settings.ini` (Plasma
      writes one) overrides the GTK settings. After tint2 the autostart runs `dex -a -e Openbox`, which
      starts the XDG autostart entries (`/etc/xdg/autostart`, `~/.config/autostart`): nm-applet,
      blueman-applet and pasystray in the tray, and kgpg, pam_kwallet_init, xapp-sn-watcher and
      xdg-user-dirs-update when installed; openbox-autostart's own `openbox-xdg-autostart` needs
      python-pyxdg and runs nothing without it. A `.desktop` file with `Hidden=true` in
      `~/.config/autostart` turns one off. The environment sets `QT_QPA_PLATFORMTHEME=gtk3` and unsets
      `QT_STYLE_OVERRIDE`, so Qt 5 and 6 apps follow the GTK theme: Artix's `/etc/environment` (from
      pam) sets both to `gtk4`, which is no Qt plugin, and Qt fell back to light Fusion. Notifications:
      `/etc/dunst/dunstrc.d/50-homestead.conf`, a drop-in over dunst's own `/etc/dunst/dunstrc` (dunst
      reads `/etc/dunst`, not `/etc/xdg`, while `XDG_CONFIG_DIRS` is unset; a `~/.config/dunst/dunstrc`
      replaces both). KDE apps: `/etc/xdg/kdeglobals` with the Homestead colours, Fusion, Homestead
      icons and Sans Serif 11, and the `Homestead` scheme in `/usr/share/color-schemes` (KDE apps read
      the colours from kdeglobals itself, so they are repeated there). An Artix ISO install copies a
      `~/.config/kdeglobals` (Artix-dark) from `/etc/skel` that overrides it; move it away to get
      Homestead's. Depends on dex, breeze-icons, ttf-dejavu, xcursor-neutral, and
      xed, playerctl and mpv-mpris, which pulls mpv (key bindings), brightnessctl and libnotify
      (homestead-osd); zenity (tint2 clock) and geany (menu's config editor) are
      optional. The `firefox-nightly` key binding has no Artix package (Superseded: `firefox-nightly-bin`
      from this repo installs `/usr/bin/firefox-nightly`). Licence unknown: the theme is
      the owner's, `KDE-classic`'s source is unknown, six sounds are sound-theme-freedesktop's.
      Upgrading from `openbox-homestead` 2, `tint2-homestead` 1 or `obmenu-generator` 1 leaves their
      stock files in place (pacman keeps existing `/etc` files) and installs Homestead's as `.pacnew`:
      move each `.pacnew` over its file (`/etc/xdg/openbox/*`, `/etc/xdg/tint2/tint2rc`,
      `/etc/xdg/obmenu-generator/schema.pl`). A fresh install gets Homestead's directly.
    - `homestead-wallpapers`: 255 wallpapers in `/usr/share/backgrounds/homestead/` (artstation,
      berserk, sst, templars, wingedhussars; 300M), which the autostart's feh picks from at random.
      Most are other artists' work; licences unknown.
    - `homestead-hidpi`: 2x scaling for Retina machines only (the 2560x1600 MacBook Pro); not in
      `zpt-artix-desktop`. `/etc/X11/xinit/xinitrc.d/50-homestead-hidpi.sh`, which ly's
      `/etc/ly/setup.sh` sources at X login, exports `GDK_SCALE=2` and `GDK_DPI_SCALE=0.5` (GTK draws
      at 2x without doubling its fonts again), `XCURSOR_SIZE=48` and `HOMESTEAD_TINT2RC`, and merges
      `Xft.dpi: 192` and `Xcursor.size: 48` with xrdb (fonts, and Qt 6, which scales from `Xft.dpi`, so
      no `QT_SCALE_FACTOR`: it would scale twice). setup.sh runs xinitrc.d first, then merges
      `/etc/X11/Xresources` and `~/.Xresources` (a merge changes only the keys those files set, so
      they keep the hidpi values unless they set `Xft.dpi` or `Xcursor.size`), then starts
      openbox-session, whose environment keeps the `XCURSOR_SIZE` set here. `HOMESTEAD_TINT2RC` points
      the autostart's tint2 at `/usr/share/homestead/hidpi/tint2rc`: homestead-theme's tint2rc from
      the same homestead commit with only `scale_relative_to_screen_height = 800` (2x on a 1600-pixel
      panel; the build fails if any other line differs). Openbox ignores `Xft.dpi` (measured on the
      MacBook: 20 px menu rows with about 12 px text, 9 pt at 96 DPI), so the script also exports
      `XDG_CONFIG_DIRS=/usr/share/homestead/hidpi/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}`. Openbox takes the
      first `openbox/rc.xml` it finds in `~/.config`, then in `XDG_CONFIG_DIRS` in order, so it reads
      `/usr/share/homestead/hidpi/xdg/openbox/rc.xml`: homestead-theme's rc.xml with every font
      `<size>` doubled (8 to 16, 9 to 18) and the theme set to `Homestead-HiDPI` (the build fails if any
      other line differs). A `~/.config/openbox/rc.xml` still overrides it. Its menu.xml and the
      session's autostart and environment still come from `/etc/xdg`: openbox-session and
      openbox-autostart read `/etc/xdg/openbox` by path, not through `XDG_CONFIG_DIRS`.
      GTK 3 reads `/etc/gtk-3.0/settings.ini`, then `gtk-3.0/settings.ini` in each `XDG_CONFIG_DIRS`
      entry (a later file wins), then `~/.config/gtk-3.0/settings.ini`, and hands
      `gtk-cursor-theme-size` to Xcursor unscaled (GDK_SCALE does not multiply it), so
      `/usr/share/homestead/hidpi/xdg/gtk-3.0/settings.ini` is homestead-theme's settings.ini with
      only `gtk-cursor-theme-size=48` (24 there; the build fails if any other line differs); without
      it GTK 3 apps (Firefox, xed) set a 24 px cursor over their windows. A cursor size or theme in
      `~/.config/gtk-3.0/settings.ini` still overrides it. homestead-theme's gtk-4.0 settings set no
      cursor size, so there is no gtk-4.0 copy.
      `/usr/share/themes/Homestead-HiDPI` is the Homestead Openbox theme with every integer (pixel)
      value in its themerc doubled (`menu.overlap.x`, `menu.separator.padding.height`,
      `menu.border.width`, `padding.width`, `padding.height`, `window.titlebar.padding.width`,
      `window.titlebar.padding.height`, `window.button.width`, `window.button.height`,
      `window.handle.width`, `osd.border.width`; zeros stay 0, colours and textures unchanged), every
      `.xbm` button scaled 2x by pixel doubling (the build fails unless each is twice its source's
      width and height), and its index.theme renamed. `/usr/share/grub/themes/artix-hidpi` is
      artix-grub-theme's GRUB theme (GPL; the artix-branding repo states no version) at 2x, built
      from the copy installed at build time: item_font and selected_item_font are
      `DejaVu Sans Bold 32`, message-font and terminal-font `DejaVu Sans Mono Regular 32` (the names
      grub-mkfont gives `dejavu_sans_bold_32.pf2` and `dejavu_sans_mono_32.pf2`, which stay in the
      theme folder, where grub-mkconfig adds a `loadfont` for each), `item_height`, `icon_width`, `icon_height`,
      `item_icon_space` and `scrollbar_width` doubled (zeros and percentages unchanged; the build fails
      if any other theme.txt line differs), the highlight, menu, slider and userpass images scaled 2x
      nearest neighbour (the build decodes each and checks every pixel), and background.png, logo.png
      and icons/ copied unchanged; unifont.pf2 is left out, since no line uses it any more.
      Install with `sudo pacman -S homestead-hidpi` and log in again. Depends on homestead-theme and
      xorg-xrdb; builds with python, artix-grub-theme, grub (grub-mkfont) and ttf-dejavu.
      The package can't reach the text console, where ly draws with the console font; that is a
      manual step on each Retina machine (`/etc/conf.d/consolefont` belongs to `openrc`):
      set `consolefont="ter-v32b"` there (Terminus 16x32, from `terminus-font`), then
      `sudo rc-update add consolefont boot`. It applies to tty1-12 from the next boot. The GRUB
      theme is manual too (`/etc/default/grub` belongs to `grub`):
      `sudo cp /etc/default/grub /etc/default/grub.pre-hidpi`, set
      `GRUB_THEME="/usr/share/grub/themes/artix-hidpi/theme.txt"` there, then
      `sudo grub-mkconfig -o /boot/grub/grub.cfg`. Package updates need no re-run: GRUB reads the
      theme and its fonts from that folder at boot. To undo,
      `sudo cp /etc/default/grub.pre-hidpi /etc/default/grub && sudo grub-mkconfig -o /boot/grub/grub.cfg`.
  - Desktop tools in no Artix repo, built from Arch's or the AUR's PKGBUILD (named in each one's
    first line), unchanged unless noted:
    - `wmctrl` 1.07 (Arch): tarball from Debian's archive, same sha512 (web.archive.org serves
      Arch's URL decompressed).
    - `dex` 0.10.1 (Arch).
    - `obmenu-generator` 0.93 (AUR); its `openbox` dependency is met by `openbox-homestead`. Without
      `/etc/xdg/obmenu-generator/schema.pl`, which comes from `homestead-theme`.
    - `perl-linux-desktopfiles` 0.26 (AUR), needed by `obmenu-generator`.
    - `xcursor-neutral` 1.13a (AUR): source from the mirror its PKGBUILD names, same sha256
      (distribute.kde.org no longer serves it).
  - `zpt-artix-desktop`: meta-package for the whole desktop; its one file,
    `/etc/xdg/mimeapps.list`, makes `thunar.desktop` the default for `inode/directory`, so
    `xdg-open` on a folder (the Openbox menu's File Manager) opens Thunar: under Openbox there is no
    `XDG_CURRENT_DESKTOP`, and xdg-mime would otherwise take the first handler in `mimeinfo.cache`,
    `kitty-open.desktop`. An `inode/directory` line in `~/.config/mimeapps.list` still overrides it.
    It depends on the homestead X stack,
    xinit/xrandr/xset/xkill, xclip, xdotool, wmctrl, `ly` + `ly-openrc`, session tools (obmenu-generator,
    dex, dunst, feh,
    polkit-gnome, lxappearance-obconf, xdg-user-dirs-gtk, xdg-desktop-portal-gtk, slock, redshift,
    flameshot, scrot), Thunar with its plugins, tumbler, gvfs and archivers, PipeWire with
    `pipewire-openrc`/`pipewire-pulse-openrc`/`wireplumber-openrc`, pavucontrol, pasystray,
    alsa-utils (amixer, for the volume keys),
    `networkmanager-openrc`, network-manager-applet, nss-mdns, `bluez-openrc`, blueman, kitty,
    fonts (with ttf-dejavu, the kitty config's DejaVu Sans Mono), the xcursor-neutral cursor theme,
    `homestead-theme` and `homestead-wallpapers`, upower and `power-profiles-daemon-openrc`. No GPU
    drivers or microcode (per machine).
  - Apps in no Artix repo that need Electron 43 (Artix's newest is electron42), so they ship as
    upstream's prebuilt binaries with their own bundled Electron, from the AUR's `-bin` PKGBUILD
    (named in each one's first line):
    - `obsidian-bin` 1.15.1 (proprietary licence): the AUR's PKGBUILD (which pins the older 1.8.10)
      bumped to Arch's obsidian 1.15.1: upstream's Linux tarball in `/opt/Obsidian`, plus Arch's
      desktop file, MIME types and licence, all with Arch's sha256sums. `/usr/bin/obsidian` is a
      symlink; the install script sets `chrome-sandbox` setuid only when unprivileged user
      namespaces are unavailable.
    - `heroic-games-launcher-bin` 2.22.4 (AUR, unchanged; upstream's
      `Heroic-2.22.4-linux-x64.pacman`, in `/opt/Heroic`).
  - `firefox-nightly-bin` (MPL/GPL/LGPL): the AUR's PKGBUILD (which pins one dated build), changed so
    every build is Mozilla's current Nightly: its version and buildid come from the newest
    `firefox-<version>.en-US.linux-x86_64.json` in Mozilla's `latest-mozilla-central`, cached in
    `latest.txt` (not committed) for an hour so one build sees one Nightly. The tarball is checked
    against its `.asc` and Mozilla's release key in `keys/pgp` (fingerprint
    `14F26682D0916CDD81E37B6D61B7B526D98F0353`); it has no fixed sha512. Installed into
    `/usr/lib/firefox-nightly`, with `/usr/bin/firefox-nightly`, `firefox-nightly.desktop` and the
    AUR's `policies.json`, which turns off Firefox's own updater: pacman updates it, from
    `.github/workflows/nightly.yml` (see [CI](#ci)). Firefox keeps a profile per install folder, so
    after moving from the tarball it opens a new profile: pick the old one in `about:profiles`.
  - Apps and libraries in no Arch or Artix repo, built from the AUR's PKGBUILD (named in each
    one's first line), unchanged: `vkbasalt` 0.3.2.10, `simple-mtpfs` 0.4.0,
    `jmtpfs` 0.5, `amdtop` 0.2.6, `python311` 3.11.18, `libpng12` 1.2.59, `ocs-url` 3.1.0, and
    `bpftune-git`, which builds upstream's newest commit (its version changes with each build; it
    installs a systemd unit, unused on OpenRC). Superseded: `parole-git` was built here until
    `zpt-artix-apps` 1-7 swapped it for mpv; the package is gone from the repo.
  - `zpt-artix-apps`: meta-package for everyday apps: `firefox-nightly-bin`, thunderbird, `obsidian-bin`,
    qbittorrent, mpv, steam, lutris, `heroic-games-launcher-bin`, mangohud, gamemode,
    gamescope, protontricks, git, github-cli, htop, fastfetch, ripgrep, flatpak, lact with
    `lact-openrc`, `zpt-artix-gaming`, goverlay, vkd3d, lib32-vkd3d, piper, solaar, and the AUR
    packages above. Its optdepends name the rest, which a stock
    zpt-artix install can't resolve: ghidra, gitea-cli, fsarchiver, efitools,
    nano-syntax-highlighting, lib32-mangohud, umu-launcher, antimicrox, openrgb (Arch
    `[extra]`/`[multilib]` only), the AUR's
    `electron-cash-git` and `arch-update` (they need Arch `[extra]` packages; `arch-update` also
    depends on `systemd`), `bpftune-openrc`, and four AUR packages this repo doesn't build:
    `lib32-vkbasalt` (its build deps are in `[lib32]`, which the build container doesn't enable),
    `reshade-shaders-git` (its build downloads 45 third-party shader packs from unpinned branch
    zips, with no checksums and licences that weren't reviewed), `virtio-win` (an 877 MB ISO) and
    `synergy3-bin` (proprietary; its build fetches Symless's package with a download token). Install
    those from the AUR with an AUR helper. `steam` and `lib32-vkd3d` are in
    Artix's `[lib32]` repo, which Artix's default `pacman.conf` leaves off: enable it first. No
    browser since 1-3: Firefox Nightly has no Artix package, so it is Mozilla's tarball
    (`https://download.mozilla.org/?product=firefox-nightly-latest-ssl&os=linux64&lang=en-US`)
    unpacked into a user-writable folder such as `~/.local/share/firefox-nightly`, where it updates
    itself, with `~/.local/bin/firefox-nightly` linked to its `firefox` (the name the Homestead
    rc.xml runs) and a `firefox-nightly.desktop`. Upgrading from 1-2 leaves firefox installed;
    `sudo pacman -Rs firefox` removes it. Superseded since 1-5: it depends on `firefox-nightly-bin`
    (above). A tarball install left in place still wins, as `~/.local/bin/firefox-nightly` and
    `~/.local/share/applications/firefox-nightly.desktop` come before the package's: delete those two
    and the tarball's folder to use the package.
- Mirrored, not built: `linux-cachyos-eac` (7.3.5-2) and `cachyos-eac-signing-key` (1-2) are
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
  `repo/zpt-artix.db.tar.zst`. `MAKEPKG_EXTRA` adds makepkg flags. Before makepkg it imports the package's `keys/pgp/*.asc` (the AUR
  layout; `libpng12` has one) into the build user's gpg keyring, so makepkg can check the source
  signature against `validpgpkeys` in a fresh container. It skips the dep check for
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
- `.github/workflows/repo.yml`, `.github/workflows/nightly.yml`: CI, see [CI](#ci).

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

`.github/workflows/nightly.yml` runs daily (11:43 UTC) and by hand (`gh workflow run nightly`). It
rebuilds only `firefox-nightly-bin`, so plain `sudo pacman -Syu` gets Mozilla's current Nightly. In
the same container it reads the Nightly's version from Mozilla and stops if the release already has
that package; else it builds it with `build.sh`, downloads the published `zpt-artix.db`/`.files`,
signs the package and db as above (`repo-add --verify` checks the published db's signature first),
and on `master` uploads the package, then the db, then deletes the old `firefox-nightly-bin`
assets. It shares `repo.yml`'s concurrency group, so the two never write the release at once; a
run that starts while another waits cancels the waiting one.

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

## Arch repos

For packages only Arch has (and AUR packages that need them), add Arch's `[extra]` and
`[multilib]`. First install `artix-archlinux-support` (Artix `[galaxy]`): it creates
`/etc/pacman.d/mirrorlist-arch`, and until that file exists pacman refuses to parse a
`pacman.conf` that includes it. It also provides (and conflicts with) `systemd`, `systemd-libs` and
`libsystemd` as a dummy, so AUR packages that list systemd as a dependency install.

```sh
sudo pacman -S artix-archlinux-support
```

Then add to `/etc/pacman.conf`, after the Artix repos:

```ini
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
```

```sh
sudo pacman-key --populate archlinux
sudo pacman -Sy
```

Arch packages bring systemd units, not OpenRC scripts: look for `<name>-openrc` in Artix first
(LACT's is `lact-openrc` in `[galaxy]`), then in this repo.

## Desktop

With the repo added (above), install the meta-packages. `zpt-artix-apps` needs Artix's `[lib32]`
repo for `steam` and `lib32-vkd3d`: uncomment it in `/etc/pacman.conf` (or add `[lib32]` with
`Include = /etc/pacman.d/mirrorlist`), then `sudo pacman -Sy`.

```sh
sudo pacman -S zpt-artix-desktop zpt-artix-apps
sudo rc-update add ly default             # login: ly on tty7 (or the tty set in /etc/ly/config.ini)
sudo rc-update add NetworkManager default
sudo rc-update add bluetoothd default
sudo rc-update add power-profiles-daemon default
```

After an install from an Artix ISO, remove `/etc/local.d/0-remove-sessions.start` (unowned, left by
the installer). It deletes `/usr/share/xsessions/openbox.desktop` at every boot, so ly stops listing
Openbox. It is meant to run once and delete itself, but a stray `fi` (a syntax error) stops the shell
before that line. Then `sudo pacman -S openbox-homestead` brings the session file back.

`ly-openrc`'s service is `ly` (`/etc/init.d/ly`, supervise-daemon runs `/usr/bin/ly-dm` through
getty/agetty, `provide display-manager`); it conflicts with Artix's other display manager scripts
(`init-displaymanager`). PipeWire, pipewire-pulse and WirePlumber are OpenRC user services
(`/etc/user/init.d/`), not system services: `pam_openrc` (in `/etc/pam.d/system-login`, which ly's PAM
config reaches through `login`) starts the user's default runlevel at login. The Artix Plasma ISO
install had already added all three (`rc-update --user show`); elsewhere, `rc-update --user add
pipewire default` (and the same for `pipewire-pulse` and `wireplumber`). Tested on the 2014 MacBook
Pro (2026-11-19): ly logs into the Openbox session; with `homestead-hidpi`, the tint2 panel,
cursor, Openbox menu and title bars show at 2x. After a reboot (2026-11-20): the GRUB menu
shows the 2x `artix-hidpi` theme, the console uses `ter-v32b`, ly still lists Openbox with
`0-remove-sessions.start` removed, and the volume and screen brightness popups show after login.
