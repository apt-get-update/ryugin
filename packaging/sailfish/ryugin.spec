# Ryūgin for Sailfish OS (aarch64): a native Silica UI on Keel (Silica on Qt 6, from Reef's
# repo), Qt 6 (6.8) from the Chum testing repo. Built by make phone: see README.adoc,
# "Sailfish OS".
Name:       ryugin
Version:    2.0.0~beta1
Release:    1
Summary:    Navidrome player with synced lyrics (Go + Qt 6 QML)
License:    AGPL-3.0-or-later
URL:        https://git.neptune.one/dragon/ryugin
BuildRequires: pkgconfig(Qt6Widgets)
BuildRequires: pkgconfig(Qt6Qml)
BuildRequires: qt6-qtdeclarative-devel
BuildRequires: qt6-qtmultimedia-devel
BuildRequires: qt6-qtshadertools
Requires:   shipwright-keel-silica
Requires:   shipwright-keel-sailfishapp
Requires:   qt6-qtdeclarative
Requires:   qt6-qtmultimedia
Requires:   qt6-qtimageformats
Requires:   qt6-qtwayland
Requires:   qt6-sfos-maliit-platforminputcontext

%description
A Navidrome player after SPlayer-Next: library, fullscreen player with synced lyrics,
colours from the cover, MPRIS for the lock screen.

%prep
# Built by packaging/sailfish/build.sh on the build machine, from the source tree (%{src}).

%build
[ -x %{src}/%{name} ] || { echo "run packaging/sailfish/build.sh (make phone): it builds %{name} first" >&2; exit 1; }

%install
cd %{src}
install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}
install -d %{buildroot}%{_datadir}/%{name}
cp -r qml qml-sailfish %{buildroot}%{_datadir}/%{name}/ # qml-sailfish/ uses qml/'s Api, Player, Theme
install -Dm644 packaging/sailfish/%{name}.desktop %{buildroot}%{_datadir}/applications/%{name}.desktop
# Settings › Apps › Ryūgin: the cache, its size, clearing it.
install -Dm644 packaging/sailfish/settings/%{name}.json %{buildroot}%{_datadir}/jolla-settings/entries/%{name}.json
install -Dm644 packaging/sailfish/settings/settings.qml %{buildroot}%{_datadir}/%{name}/settings/settings.qml
for n in 86 108 128 172; do
    install -Dm644 packaging/sailfish/icons/$n.png %{buildroot}%{_datadir}/icons/hicolor/${n}x${n}/apps/%{name}.png
done

%post
# Sailjail: the caches and the settings (2.0.0 beta 1's) move to the app's own folders.
for h in /home/*; do
    for d in .cache .config; do
        if [ -d "$h/$d/ryugin" ] && [ ! -e "$h/$d/dragon/ryugin/ryugin" ]; then
            mkdir -p "$h/$d/dragon/ryugin"
            mv "$h/$d/ryugin" "$h/$d/dragon/ryugin/ryugin"
            chown -R "$(stat -c %u:%g "$h")" "$h/$d/dragon"
        fi
    done
done
exit 0

%files
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/jolla-settings/entries/%{name}.json
%{_datadir}/icons/hicolor/*/apps/%{name}.png
