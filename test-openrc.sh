#!/bin/sh
# Automate the manual checks of an OpenRC service: start/stop, supervise-daemon respawn, reload.
# Usage: sudo ./test-openrc.sh <service>  (on the Artix machine). Prints PASS/FAIL per step,
# exits non-zero if any failed, and leaves the service started or stopped as it found it.
svc=$1
f=/etc/init.d/$svc
[ -n "$svc" ] && [ -f "$f" ] || { echo "usage: sudo $0 <service>  (no $f)"; exit 2; }
# First top-level assignment of $1 in the init script, quotes stripped.
var() { sed -n "s/^$1=[\"']\{0,1\}\([^\"']*\).*/\1/p" "$f" | head -n1; }
cmd=$(var command)
supervisor=$(var supervisor)
extra="$(var extra_started_commands) $(var extra_commands)"
pidfile=$(var pidfile)
[ -n "$cmd" ] || { echo "no command= in $f"; exit 2; }
failed=0
check() { if "$@" >/dev/null 2>&1; then echo "PASS: $step"; else echo "FAIL: $step"; failed=1; fi; }
started() { rc-service "$svc" status 2>&1 | grep -q 'status: started'; }
stopped() { ! started; }
# supervise-daemon's pidfile holds the supervisor's PID, not the daemon's, so look up the command
# by name unless the script names its own pidfile.
dpid() {
  if [ -n "$pidfile" ] && [ "$supervisor" != supervise-daemon ]; then
    p=$(cat "$pidfile" 2>/dev/null) && kill -0 "$p" 2>/dev/null && echo "$p"
  else
    pidof -s "${cmd##*/}"
  fi
}
running() { [ -n "$(dpid)" ]; }
gone() { ! running; }

if started; then was=started; else was=stopped; fi
rc-service "$svc" stop >/dev/null 2>&1
step="start"; check rc-service "$svc" start
step="status says started"; check started
sleep 1
step="daemon $cmd running"; check running
step="stop"; check rc-service "$svc" stop
step="status says stopped"; check stopped
step="no daemon left"; check gone

if [ "$supervisor" = supervise-daemon ]; then
  rc-service "$svc" start >/dev/null 2>&1; sleep 1
  old=$(dpid)
  [ -n "$old" ] && kill -9 "$old"
  sleep 5
  new=$(dpid)
  # An instance that exits right away (and gets respawned again) would have a new PID by now.
  sleep 2
  respawned() { [ -n "$old" ] && [ -n "$new" ] && [ "$old" != "$new" ] && [ "$(dpid)" = "$new" ]; }
  step="respawn after kill -9 (old ${old:-none}, new ${new:-none})"; check respawned
fi

case " $extra " in *" reload "*)
  started || rc-service "$svc" start >/dev/null 2>&1
  step="reload"; check rc-service "$svc" reload
  step="still running after reload"; check running ;;
esac

if [ $was = started ]; then rc-service "$svc" start; else rc-service "$svc" stop; fi >/dev/null 2>&1
# status can still say started while supervise-daemon is giving up, so check the daemon too.
restored() { if [ $was = started ]; then sleep 1; started && running; else stopped; fi; }
step="restored to $was"; check restored
echo "Boot check is manual: rc-update add $svc default, reboot, then rc-status shows $svc started."
exit $failed
