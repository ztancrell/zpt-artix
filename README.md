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
