#!/bin/sh
# tests/silica.sh PHONE [PAGE...]: Ryūgin's Silica UI (Keel) on a Sailfish OS phone, from
# this PC, with a picture of each page. Builds (packaging/sailfish/build.sh,
# NOBUILD=1 skips it), copies the binary, qml/ and qml-sailfish/ to ~/ryugin-silica on the
# phone (nothing is installed; Keel must be), starts it once per page (RYUGIN_PAGE, empty:
# the first page) and saves the window as tests/phone/<page>.png, with the log beside it.
# PLAY=1 plays first (MPRIS); the page "cover" draws the home screen's card over the
# window. PAUSE=1 pauses after playing. SCROLL=1 keeps it open 60 s and logs where the
# page is each frame it moves ("scroll:"), while someone scrolls it. LANDSCAPE=1 turns
# the device to landscape. PERF=1 opens and closes a page for 20 s and logs the slow
# frames ("perf:"); PERF=Page:fling flings the page's list instead. Each run logs the
# app's memory before it quits ("mem:"). KEYBOARD=1 opens the keyboard on the page's first text field.
# LOCALE (e.g. en_GB.utf8): the app's language, else the phone's.
# Each run then checks the app still runs and quits when asked (as closing its card asks),
# and fails on a crash; the script exits 1 if any page failed.
set -e
cd "$(dirname "$0")/.."
phone=${1:?usage: tests/silica.sh PHONE [PAGE...]}
shift
[ -n "$NOBUILD" ] || packaging/sailfish/build.sh >/dev/null
tar cf - ryugin qml qml-sailfish | ssh "$phone" 'rm -rf ryugin-silica && mkdir ryugin-silica && tar xf - -C ryugin-silica'
mkdir -p tests/phone
out=$(mktemp)
trap 'rm -f "$out"' EXIT
for page in "${@:-home}"; do
    [ "$page" = home ] && p= || p=$page
    ssh "$phone" "sh -s '$p' '$PLAY' '$PAUSE' '$SCROLL' '$LANDSCAPE' '$PERF' '$KEYBOARD' '$LOCALE'" <<'EOF'
dir=$HOME/ryugin-silica
log=$HOME/.cache/dragon/ryugin/ryugin/ryugin.log
# Until every copy is gone: one still on D-Bus makes the next show it and quit (one copy).
pkill -f '^/usr/bin/ryugin' || true; pkill -f "^$dir/ryugin" || true
i=0; while pgrep -f "ryugin$|ryugin " >/dev/null && [ $i -lt 20 ]; do sleep 0.5; i=$((i + 1)); done
dbus-send --system --type=method_call --dest=com.nokia.mce /com/nokia/mce/request com.nokia.mce.request.req_display_state_on
rm -f /tmp/ryugin-shot.png "$log" # an old "shot:" would end the run at once
. /etc/locale.conf 2>/dev/null; [ -z "$8" ] || LANG=$8; export LANG
RYUGIN_QML=$dir/qml-sailfish RYUGIN_PAGE=$1 RYUGIN_SHOT=/tmp/ryugin-shot.png RYUGIN_SCROLL=$4 RYUGIN_LANDSCAPE=$5 RYUGIN_PERF=$6 RYUGIN_KEYBOARD=$7 setsid "$dir/ryugin" </dev/null >/dev/null 2>&1 &
if [ -n "$2" ]; then
    sleep 3
    dbus-send --session --type=method_call --dest=org.mpris.MediaPlayer2.ryugin /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Play
    [ -z "$3" ] || { sleep 2; dbus-send --session --type=method_call --dest=org.mpris.MediaPlayer2.ryugin /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Pause; }
fi
# The picture is whole once the log says so.
i=0; while ! grep -q "^.*shot:" "$log" 2>/dev/null && [ $i -lt 30 ]; do sleep 0.5; i=$((i + 1)); done
[ -z "$4" ] || sleep 60
[ -z "$6" ] || sleep 18
[ -z "$7" ] || sleep 3 # the keyboard opens at 3 s
# Still running, then gone within 3 s of a quit (MPRIS Quit: the card's close asks the same).
if ! pgrep -f "^$dir/ryugin" >/dev/null; then
    echo "FAIL   : not running any more (a crash?)"
else
    pid=$(pgrep -f "^$dir/ryugin" | head -1)
    awk '/^VmRSS/ { r = $2 } /^RssAnon/ { a = $2 } /^Threads/ { t = $2 } END { printf "mem: rss %d MB, own %d MB, threads %d\n", r / 1024, a / 1024, t }' "/proc/$pid/status"
    dbus-send --session --type=method_call --dest=org.mpris.MediaPlayer2.ryugin /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Quit
    i=0; while pgrep -f "^$dir/ryugin" >/dev/null && [ $i -lt 12 ]; do sleep 0.25; i=$((i + 1)); done
    if pgrep -f "^$dir/ryugin" >/dev/null; then echo "FAIL   : did not quit"; pkill -9 -f "^$dir/ryugin"; fi
fi
grep -q "native crash\|SIGSEGV\|fatal error" "$log" && echo "FAIL   : a crash in the log"
grep "keyboard:" "$log" || true
EOF
    scp -q "$phone:/tmp/ryugin-shot.png" "tests/phone/$page.png" || echo "FAIL   : no picture of $page"
    scp -q "$phone:.cache/dragon/ryugin/ryugin/ryugin.log" "tests/phone/$page.log"
    grep -E "\[W\]|\[C\]|qml:.*rror" "tests/phone/$page.log" | grep -v "swap buffers\|libGLES_mali\|mapper.mediatek" || true
done 2>&1 | tee "$out"
! grep -q "^FAIL" "$out"
