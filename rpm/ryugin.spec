# Ryūgin for Sailfish OS (aarch64), Qt 6 (6.8) from the Chum testing repo,
# started by qt-runner. Built by ./sailfish.sh: see README.adoc, "Sailfish OS".
Name:       ryugin
Version:    1.0.0
Release:    1
Summary:    Navidrome player with synced lyrics (Go + Qt 6 QML)
License:    AGPL-3.0-or-later
URL:        https://git.neptune.one/dragon/ryugin
BuildRequires: pkgconfig(Qt6Widgets)
BuildRequires: pkgconfig(Qt6Qml)
BuildRequires: qt6-qtdeclarative-devel
BuildRequires: qt6-qtmultimedia-devel
BuildRequires: qt6-qtshadertools
Requires:   qt-runner
Requires:   qt6-qtdeclarative
Requires:   qt6-qtmultimedia
Requires:   qt6-qtimageformats
Requires:   qt6-qtwayland
Requires:   qt6-sfos-maliit-platforminputcontext

%description
A Navidrome player after SPlayer-Next: library, fullscreen player with synced lyrics,
colours from the cover, MPRIS for the lock screen.

%prep
# Built by sailfish.sh on the build machine, from the source tree (%{src}).

%build
[ -x %{src}/%{name} ] || { echo "run ./sailfish.sh: it builds %{name} first" >&2; exit 1; }

%install
cd %{src}
install -Dm755 %{name} %{buildroot}%{_bindir}/%{name}
install -d %{buildroot}%{_datadir}/%{name}
cp -r qml %{buildroot}%{_datadir}/%{name}/
install -Dm644 rpm/%{name}.desktop %{buildroot}%{_datadir}/applications/%{name}.desktop
for n in 86 108 128 172; do
    install -Dm644 rpm/icons/$n.png %{buildroot}%{_datadir}/icons/hicolor/${n}x${n}/apps/%{name}.png
done

%files
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
