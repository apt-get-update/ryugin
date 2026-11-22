#!/bin/sh
# tests/phone.sh PHONE [ROUNDS]: Ryūgin's bench on a Sailfish OS phone, from this PC.
# Builds (packaging/sailfish/build.sh, NOBUILD=1 skips it), copies the binary and qml/ to ~/ryugin-bench
# on the phone (nothing is installed) and, each round, starts it under qt-runner, plays
# (MPRIS: 50 random songs), skips, sends it behind another app and back (lipstick), and
# measures CPU, memory, frames and the playback speed. Fails on a crash, on a window
# that draws nothing when back in front, on silence, or on slow or fast playback.
# Logs land in tests/phone/. The phone stays unlocked, screen on.
set -e
cd "$(dirname "$0")/.."
phone=${1:?usage: tests/phone.sh PHONE [ROUNDS]}
rounds=${2:-3}
[ -n "$NOBUILD" ] || packaging/sailfish/build.sh >/dev/null
tar cf - ryugin qml | ssh "$phone" 'rm -rf ryugin-bench && mkdir ryugin-bench && tar xf - -C ryugin-bench'
rm -rf tests/phone && mkdir -p tests/phone
status=0
ssh "$phone" sh -s "$rounds" <<'EOF' || status=$?
rounds=$1
dir=$HOME/ryugin-bench
log=$HOME/.cache/ryugin/ryugin.log
fail=0
bad() { echo "FAIL   : $*"; fail=1; }
mce() { dbus-send --system --type=method_call --dest=com.nokia.mce /com/nokia/mce/request com.nokia.mce.request.$1; }
player() { dbus-send --session --type=method_call --dest=org.mpris.MediaPlayer2.ryugin /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.$1; }
prop() {
    dbus-send --session --print-reply --dest=org.mpris.MediaPlayer2.ryugin /org/mpris/MediaPlayer2 \
        org.freedesktop.DBus.Properties.Get string:org.mpris.MediaPlayer2.Player string:$1 2>/dev/null |
        awk 'NR > 1 { v = $NF } END { gsub(/"/, "", v); print v }'
}
front() { dbus-send --session --type=method_call --dest=org.nemomobile.lipstick /WindowModel local.Lipstick.WindowModel.raiseProcessWindow string:$1; }
# Until it is gone: a copy still on D-Bus makes the next one show it and quit (one copy).
stop() {
    pkill -f "qt-runner $dir/ryugin" || true; pkill -f "^$dir/ryugin" || true
    i=0; while pgrep -f "^$dir/ryugin" >/dev/null && [ $i -lt 20 ]; do sleep 0.5; i=$((i + 1)); done
    sleep 1
}
cpu() { awk '{ print $14 + $15 }' /proc/$1/stat 2>/dev/null || echo 0; }  # ticks (1/100 s)
# Each thread's name and CPU ticks, to see which ones are busy.
threads() { for t in /proc/$1/task/*; do echo "$(tr ' ' _ <$t/comm) $(awk '{ print $14 + $15 }' $t/stat)"; done 2>/dev/null; }
rss() { awk '/^Rss/ { r = $2 } /^Anonymous/ { a = $2 } END { printf "%d MB (%d MB its own)", r / 1024, a / 1024 }' /proc/$1/smaps_rollup 2>/dev/null; }
alive() { [ -d /proc/$1 ] || { bad "crashed (round $r): $(grep -A3 'native crash' "$log" | head -4 | tr '\n' ' ')"; return 1; }; }
# Frames drawn in the 3 s after the last "active: true", as Main.qml logs them.
drawn() { awk '/qt-runner active: true/ { n = "" } /frames drawn in 3 s/ { n = $0; sub(/.*3 s: /, "", n); sub(/ .*/, "", n) } END { print n }' "$log"; }
# Other app in front: the clock, opened once (its window: not the hidden -prestart one) and
# closed at the end if the bench opened it.
other=jolla-clock
opened=
pgrep -f "^/usr/bin/$other$" >/dev/null || { invoker --type=silica-qt5 -n $other >/dev/null 2>&1 & opened=1; sleep 4; }

stop
pkill -f "qt-runner /usr/bin/ryugin" || true # the installed copy: only one runs
r=0
while [ $r -lt "$rounds" ]; do
    r=$((r + 1))
    mce req_display_state_on; mce req_display_blanking_pause
    start=$(date +%s)
    setsid qt-runner $dir/ryugin --bench </dev/null >/dev/null 2>&1 &
    # A quick swipe away as the window appears (0.3, 1, then 2 s), back 3 s later.
    early=$(echo "$r" | awk '{ print $1 == 1 ? 0.3 : $1 == 2 ? 1 : 2 }')
    sleep "$early"; front $other; sleep 3; front qt-runner
    pid=
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 1
        pid=$(pgrep -f "^$dir/ryugin" | head -1)
        [ -n "$pid" ] && grep -q "start, pid $pid" "$log" 2>/dev/null && grep -q "qt-runner active: true" "$log" && break
    done
    [ -n "$pid" ] || { bad "no start (round $r)"; stop; continue; }
    up=$(($(date +%s) - start))
    sleep 4
    alive $pid || { cp "$log" $dir/crash-$r.log; stop; continue; }
    n=$(drawn)
    [ "${n:-0}" -gt 0 ] || bad "blank after a swipe ${early} s after opening (round $r): ${n:-no} frames"

    # Play: 50 random songs; after 4 s, the next one; then 20 s of playback, timed (MPRIS's
    # position comes each second: ±5 %).
    player Play; sleep 4
    alive $pid || { cp "$log" $dir/crash-$r.log; stop; continue; }
    # Between two songs MPRIS stays Playing (a Stopped flashed the cover's idle grid).
    dbus-monitor --session "type=signal,path=/org/mpris/MediaPlayer2" >$dir/skip.txt 2>&1 &
    mon=$!
    sleep 0.5; player Next; sleep 3.5
    kill $mon
    alive $pid || { cp "$log" $dir/crash-$r.log; stop; continue; }
    grep -q '"Stopped"' $dir/skip.txt && bad "MPRIS said Stopped while skipping (round $r)"
    [ "$(prop PlaybackStatus)" = Playing ] || bad "not playing (round $r): $(prop PlaybackStatus)"
    threads $pid >$dir/threads0; c0=$(cpu $pid); p0=$(prop Position)
    sleep 20
    p1=$(prop Position); c1=$(cpu $pid); threads $pid >$dir/threads1
    cpuPlay=$(( (c1 - c0) / 20 )) # % of one core, playing
    speed=$(( (${p1:-0} - ${p0:-0}) / 200000 )) # in % of real time
    [ $speed -ge 90 ] && [ $speed -le 110 ] || bad "playback at $speed % of real time (round $r)"
    pactl list short sink-inputs >$dir/sinks-$r.txt
    # Pause and play again: MPRIS (the lock screen) must follow.
    player Pause; sleep 2; q0=$(prop Position); s0=$(prop PlaybackStatus); sleep 2; q1=$(prop Position)
    [ "$s0" = Paused ] || bad "MPRIS says $s0 after a pause (round $r)"
    [ "$q0" = "$q1" ] || bad "MPRIS position moves while paused (round $r)"
    player Play; sleep 3; s1=$(prop PlaybackStatus); q2=$(prop Position)
    [ "$s1" = Playing ] || bad "MPRIS says $s1 after play (round $r)"
    [ "${q2:-0}" -gt "${q1:-0}" ] || bad "MPRIS position stuck after play (round $r): $q1 $q2"
    fps=$(grep "bench: fps" "$log" | tail -3 | awk '{ printf "%s ", $NF }')

    # Behind the clock for 5 s, then back: the window must draw again.
    front $other; sleep 5
    alive $pid || { cp "$log" $dir/crash-$r.log; stop; continue; }
    front qt-runner; sleep 4
    alive $pid || { cp "$log" $dir/crash-$r.log; stop; continue; }
    n=$(drawn)
    [ "${n:-0}" -gt 0 ] || bad "blank after coming back (round $r): ${n:-no} frames"
    busy=$(awk 'NR == FNR { a[$1] += $2; next } { b[$1] += $2 } END { for (n in b) if (b[n] - a[n] >= 20) printf "%s %d %%\n", n, (b[n] - a[n]) / 20 }' $dir/threads0 $dir/threads1 | sort -k2 -rn | head -6 | tr '\n' ',')
    echo "round $r: swipe at ${early} s, up ${up} s, CPU ${cpuPlay} % playing, $(rss $pid), fps ${fps}, speed ${speed} %, frames back ${n:-?}"
    echo "  busy threads (20 s of playback): ${busy:-none}"
    cp "$log" $dir/round-$r.log
    # The biggest mappings (memory, MB), for tests/phone/memory-N.txt.
    awk '/^[0-9a-f]+-/ { name = $6 ? $6 : "[anon]" } /^Rss:/ { m[name] += $2 } END { for (n in m) if (m[n] > 4096) printf "%d %s\n", m[n] / 1024, n }' /proc/$pid/smaps | sort -rn >$dir/memory-$r.txt
    player Pause
    stop
done
[ -z "$opened" ] || pkill -f "^/usr/bin/$other$" || true
[ $fail = 0 ] && echo "PASS   : $rounds rounds on the phone"
exit $fail
EOF
scp "$phone:ryugin-bench/*.log" "$phone:ryugin-bench/*.txt" tests/phone/ 2>/dev/null || true
# The logs hold Navidrome's token and salt in stream URLs: kept here only, git-ignored.
sed -i -E 's/([?&](t|s|u|p)=)[^&" ]+/\1X/g' tests/phone/*.log 2>/dev/null || true
exit $status
