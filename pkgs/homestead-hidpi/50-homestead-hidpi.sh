# homestead-hidpi: 2x scaling for Retina panels. ly's /etc/ly/setup.sh sources this at X login,
# before its own xrdb merges (they change only the keys their files set) and before openbox-session
# (homestead-theme's environment keeps an XCURSOR_SIZE set here).
export GDK_SCALE=2
export GDK_DPI_SCALE=0.5
export XCURSOR_SIZE=48
export HOMESTEAD_TINT2RC=/usr/share/homestead/hidpi/tint2rc
# Openbox ignores Xft.dpi; it reads the first openbox/rc.xml in XDG_CONFIG_DIRS, so this one (fonts and
# theme 2x) wins over /etc/xdg's. openbox-session and openbox-autostart read /etc/xdg directly.
export XDG_CONFIG_DIRS="/usr/share/homestead/hidpi/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}"
# Qt 6 on X11 scales from Xft.dpi, so no QT_SCALE_FACTOR (it would scale twice).
xrdb -merge <<'XRES'
Xft.dpi: 192
Xcursor.size: 48
XRES
