#!/bin/sh
# Every test: code quality, Go unit tests, then the QML tests (logic and UI) against a mock Navidrome,
# headless. Usage: tests/run.sh [qmltestrunner args, e.g. -functions]
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'kill "$mock" 2>/dev/null; rm -rf "$tmp"' EXIT

# Code quality: Go (.golangci.yml: vet, staticcheck, errors, complexity, length, copies)
# and QML, with no warning. qmllint's import check is off: it reports singletons that the
# qmldir declares (a qmllint bug); a broken import fails the QML tests anyway.
golangci-lint run ./...
/usr/lib/qt6/bin/qmllint -I qml --import disable -W 0 qml/*.qml
echo "PASS   : code quality (golangci-lint, qmllint)"
# Go's coverage: the unit tests and the real program's runs below, together.
cov="$tmp/cov"
mkdir -p "$cov"
make -s qm # the translations: the tests read the English, as the app loads it
# No session bus: no tray, no other player (the same in a sandbox and on a desktop).
DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent go test -covermode=atomic ./app -args -test.gocoverdir="$cov"

go build -o "$tmp/mock" ./tests/mocknavidrome
"$tmp/mock" -addr 127.0.0.1:4533 &
mock=$!
sleep 0.5

QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME="$tmp/config" QML_XHR_ALLOW_FILE_READ=1 QT_LOGGING_RULES="qt.multimedia*=false" \
    /usr/lib/qt6/bin/qmltestrunner -input tests/qml -translation qml/translations/ryugin_eng_en.qm "$@" 2>&1 | tee "$tmp/log"
grep -q "^Totals: .* 0 failed" "$tmp/log"
# A QML warning is a bug too (a bad binding, a missing property); only the headless
# platform's own notes are allowed.
if grep "^QWARN" "$tmp/log" | grep -v "PulseAudioService\|does not support raise\|does not support propagateSizeHints\|id=unresizable"; then
    echo "QML warnings" >&2
    exit 1
fi

# The real program, 6 s against the mock: Go, the tray, the global menu and Main.qml
# together must start without a QML error. No session bus, so a running player is not
# asked to show itself instead.
go build -covermode=atomic -o "$tmp/sgd" ./app
export GOCOVERDIR="$cov"
mkdir -p "$tmp/config/ryugin"
printf '[server]\nurl=http://127.0.0.1:4533\nuser=u\ntoken=t\nsalt=s\n' > "$tmp/config/ryugin/ryugin.conf"
# A KDE colour scheme (kdeglobals names it), as on Plasma: the app takes its colours.
printf '[General]\nColorScheme=Test\n' > "$tmp/config/kdeglobals"
mkdir -p "$tmp/home/.local/share/color-schemes"
printf '[Colors:Window]\nBackgroundNormal=30,26,16\nForegroundNormal=bad\n' > "$tmp/home/.local/share/color-schemes/Test.colors"
# An icon theme (hicolor here), with a sized SVG and a symbolic one (it wins), inheriting another.
icons="$tmp/home/.icons/hicolor"
mkdir -p "$icons/16/actions" "$icons/symbolic/actions"
printf '[Icon Theme]\nInherits=ryugin-test\n' > "$icons/index.theme"
svg='<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><path d="M2 2h12v12H2z"/></svg>'
echo "$svg" > "$icons/16/actions/edit-find-symbolic.svg"
echo "$svg" > "$icons/symbolic/actions/edit-find-symbolic.svg"
echo "$svg" > "$icons/symbolic/actions/go-home-symbolic.svg"
HOME="$tmp/home" QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME="$tmp/config" RYUGIN_QML="$PWD/qml" DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent \
    timeout 6 "$tmp/sgd" > "$tmp/run.log" 2>&1 || [ $? -eq 124 ]
if grep "qml/.*:[0-9]*:\|TypeError\|ReferenceError\|Binding loop" "$tmp/run.log"; then
    echo "the program logs QML errors" >&2
    exit 1
fi
echo "PASS   : the program starts cleanly"

# A broken Main.qml: it says so and exits.
mkdir "$tmp/bad"
echo "Item {" > "$tmp/bad/Main.qml"
if QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME="$tmp/config" RYUGIN_QML="$tmp/bad" DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent \
    "$tmp/sgd" 2>&1 | grep -q "QML failed to load"; then echo "PASS   : a broken Main.qml is reported"; else echo "FAIL   : a broken Main.qml" >&2; exit 1; fi

# The same program on a session bus of its own: MPRIS from QML through Go (mpris_test.go),
# and as on Sailfish OS (container_test.go).
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" RYUGIN_BIN="$tmp/sgd" go test -count=1 -run 'TestProgramOn' ./app

# 100 % of the Go code is run by the tests; the badge in the README says so.
go tool covdata textfmt -i="$cov" -o "$tmp/cov.txt"
go tool cover -func="$tmp/cov.txt" | awk '$NF != "100.0%"'
pct=$(go tool cover -func="$tmp/cov.txt" | awk '/^total:/ { print $NF }')
sed "s/PCT/$pct/g" tests/badge.svg > docs/coverage.svg
[ "$pct" = "100.0%" ] || { grep " 0$" "$tmp/cov.txt"; echo "Go coverage: $pct" >&2; exit 1; }
echo "PASS   : Go coverage $pct"
