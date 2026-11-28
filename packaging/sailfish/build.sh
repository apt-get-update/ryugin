#!/bin/sh
# Builds the Sailfish OS package (aarch64) with the Sailfish SDK, and installs it on a phone.
#
#   build.sh                 build RPMS/ryugin-*.aarch64.rpm
#   build.sh install PHONE   build, then install on the phone at PHONE (IP or name):
#                                 developer mode and SSH on, Chum with its testing repo
#
# Needs go, aarch64-linux-gnu-gcc and rpm-tools here. Everything builds on this machine; the
# SDK's engine (VirtualBox) only runs the first time, to set its target up (Chum's Qt 6) and
# copy the phone's libraries into .sysroot/ (rm -rf .sysroot to do it again).
# Env: SFOS (the SDK target's release, 5.1.0.11), SDK (~/SailfishOS). The UI is the native
# Silica one (qml-sailfish/, Keel: Silica on Qt 6).
# A package built for an older release runs on newer phones (5.1 target, 5.2 phone); the
# phone takes its Qt 6 from its own release's Chum.
set -e
cd "$(dirname "$0")/../.." # the repo
SFOS=${SFOS:-5.1.0.11}
SDK_DIR=${SDK:-$HOME/SailfishOS}
PATH=$SDK_DIR/bin:$PATH
T=SailfishOS-$SFOS-aarch64
R=$(echo "$SFOS" | cut -d. -f1,2)_aarch64 # Chum's repos: 5.1_aarch64 (Qt 6 is in testing)
target() { sfdk tools exec "$T" "$@"; }

S=$SDK_DIR/mersdk/targets/$T.default
L=$PWD/.sysroot
if [ ! -e "$L/lib/ld-linux-aarch64.so.1" ]; then
# The build engine's default route can point at the SDK's internal network (the emulator):
# send it through VirtualBox's NAT, or nothing downloads.
sfdk engine exec sudo sh -c 'PATH=/usr/sbin:/sbin:$PATH; ip route replace default via 10.0.2.2 dev eth0 2>/dev/null || { route del default; route add default gw 10.0.2.2 eth0; }' || true

if ! target ssu lr 2>/dev/null | grep -q "sailfishos:/chum:/testing/$R/"; then
    for repo in chum chum-testing; do target ssu rr $repo >/dev/null 2>&1 || true; done
    target ssu ar chum "https://repo.sailfishos.org/obs/sailfishos:/chum/$R/"
    target ssu ar chum-testing "https://repo.sailfishos.org/obs/sailfishos:/chum:/testing/$R/"
    target zypper ref -f
fi

sfdk -c target="$T" build-requires pull || true # Qt 6 (devel) into the target

# The Go binary is cross-built on this machine: the SDK's engine is 32-bit, too small for
# Go's compiler on Qt's bindings. The C/C++ parts compile with Arch's aarch64 compiler
# against the target's files (the phone's glibc and Qt); its newer libstdc++ is linked in.
# The SDK keeps only the target's headers here: its libraries are copied once from the
# engine into .sysroot/ (lib64, where Arch's compiler does not look by itself).
    sfdk engine exec sh -c "cd /srv/*/targets/$T.default && tar -cf '$PWD/.sysroot.tar' \$(ls -d usr/lib64/*.so* usr/lib64/*.a usr/lib64/*.o lib lib64 2>/dev/null)"
    rm -rf "$L" && mkdir -p "$L" && tar -C "$L" -xf .sysroot.tar && rm .sysroot.tar
    sfdk engine stop || true
fi
command -v aarch64-linux-gnu-g++ >/dev/null || { echo "install aarch64-linux-gnu-gcc" >&2; exit 1; }
export PKG_CONFIG_SYSROOT_DIR="$S" PKG_CONFIG_LIBDIR="$S/usr/lib64/pkgconfig:$S/usr/share/pkgconfig" \
    CC="aarch64-linux-gnu-gcc --sysroot=$S" CXX="aarch64-linux-gnu-g++ --sysroot=$S" \
    CGO_CFLAGS=-O2 CGO_CXXFLAGS="-O2 -Wno-sfinae-incomplete" \
    CGO_LDFLAGS="--sysroot=$L -B$L/usr/lib64 -L$L/usr/lib64 -Wl,-rpath-link,$L/usr/lib64 -static-libstdc++ -static-libgcc" \
    GO111MODULE=on GOOS=linux GOARCH=arm64 CGO_ENABLED=1 GOFLAGS=-buildvcs=false
version=$(awk '/^Version:/ { print $2 }' packaging/sailfish/ryugin.spec)
# Keel: its SailfishApp (headers, library) from Reef's repo into .keel/ (main_silica.go); the
# phone takes Keel from the same repo. Built with Chum's Qt 6.8.4, as the SDK target's.
K=$PWD/.keel KV=0.1.0-17 tags=silica
if [ ! -e "$K/usr/lib64/libkeel-sailfishapp.so" ]; then
    rm -rf "$K" && mkdir -p "$K"
    for p in shipwright-keel-sailfishapp shipwright-keel-sailfishapp-devel; do
        curl -fsSL "https://reefstore.app/sailfishos/5.2.0.22/aarch64/$p-$KV.aarch64.rpm" | (cd "$K" && rpm2cpio - | cpio -idm --quiet)
    done
fi
# A bar over the C++ files (Qt's bindings: only the first build compiles them). On an
# error, the build runs again without the bar to show it.
total=$(go list -deps -f '{{range .CXXFiles}}{{println .}}{{end}}' ./app | grep -c . || true)
if ! { go build -x -trimpath -tags "$tags" -ldflags "-s -w -X main.version=$version" -o ryugin ./app 2>&1; echo "exit $?"; } | awk -v total="$total" '
    /^exit [0-9]+$/ { code = $2 }
    match($0, / -c [^ ]*\.cpp/) {
        n++; if (total < n) total = n; w = int(30 * n / total)
        printf "\r[%s%s] %d/%d %-36s", substr(bar, 1, w), substr(dots, 1, 30 - w), n, total, substr($0, RSTART + 4, RLENGTH - 4)
        fflush()
    }
    BEGIN { bar = "##############################"; dots = ".............................." }
    END { if (n) print ""; exit code }'; then
    go build -trimpath -tags "$tags" -ldflags "-s -w -X main.version=$version" -o ryugin ./app
    exit 1
fi

make -s qm # the translations

# The package, by this machine's rpmbuild: the shaders are the committed .qsb (format 9,
# which the phone's Qt 6.8 reads); no strip or debug package (x86 tools, arm binary).
command -v rpmbuild >/dev/null || { echo "install rpm-tools" >&2; exit 1; }
rpmbuild -bb --target aarch64-linux --nodeps --quiet \
    --define "_topdir $PWD/.rpmbuild" --define "_rpmdir $PWD/RPMS" --define "src $PWD" \
    --define "_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
    --define "debug_package %{nil}" --define "__os_install_post %{nil}" \
    --define "_binary_payload w9.gzdio" --define "_rpmformat 4" packaging/sailfish/ryugin.spec
rm -rf .rpmbuild
rpm=$(ls -t RPMS/ryugin-*.aarch64.rpm | head -1)
echo "built: $rpm"

if [ "$1" = install ]; then
    [ -n "$2" ] || { echo "usage: $0 install PHONE" >&2; exit 1; }
    # Keel comes from Reef's repo, which Reef's installer adds.
    scp "$rpm" "defaultuser@$2:"
    # Chum and its testing repo (Qt 6) for the phone's own release, once.
    ssh -t "defaultuser@$2" "devel-su sh -c '. /etc/os-release; r=\$(echo \$VERSION_ID | cut -d. -f1,2)_aarch64
        ssu lr | grep -q chum:/testing/\$r/ || { ssu ar chum https://repo.sailfishos.org/obs/sailfishos:/chum/\$r/
            ssu ar chum-testing https://repo.sailfishos.org/obs/sailfishos:/chum:/testing/\$r/; pkcon -y refresh; }
        pkcon -y install-local $(basename "$rpm")'"
    # A running copy is the old one, and only one runs: close it, the next start is new.
    ssh "defaultuser@$2" 'pkill -f "^/usr/bin/ryugin"' || true
fi
