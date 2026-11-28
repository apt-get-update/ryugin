# Ryūgin's packages and checks. `make` lists the targets.
# arch: the newest release tag; arch-git (ryugin-git) and phone: this working tree
# (uncommitted changes included).
# PHONE: the Jolla phone's IP or name (SSH as defaultuser), e.g. `make phone-install PHONE=10.0.0.5`.
# QSB: Qt's shader compiler; use the one of the Qt that runs the app (an older Qt cannot
# read a newer .qsb).
PHONE ?=
QSB ?= /usr/lib/qt6/bin/qsb
# lupdate: Qt 5's (Arch's Qt 6 one is built without QML); lrelease: Qt 6's.
LUPDATE ?= /usr/bin/lupdate
LRELEASE ?= /usr/lib/qt6/bin/lrelease
ARCH = packaging/arch
SAILFISH = packaging/sailfish/build.sh

.PHONY: help all arch arch-install arch-git arch-git-install phone phone-install phone-test test bench shaders ts qm clean need-phone

help:
	@echo "make arch            Arch package of the release ($(ARCH)/*.pkg.tar.zst)"
	@echo "make arch-install    build and install it here"
	@echo "make arch-git        Arch package of the working tree (ryugin-git)"
	@echo "make arch-git-install build and install it here"
	@echo "make phone           Sailfish OS package (RPMS/*.aarch64.rpm)"
	@echo "make phone-install   build and install it on PHONE"
	@echo "make all             both packages"
	@echo "make test            lint and every test (tests/run.sh)"
	@echo "make phone-test      every page on PHONE, the keyboard, landscape, quitting"
	@echo "make bench           page switches on PHONE, slow frames (PERF=1 tests/silica.sh)"
	@echo "make ts              update the translations (qml/translations/*.ts) from the code"
	@echo "make qm              compile them for the app (build, packages and tests do it)"
	@echo "make shaders         compile qml/ shaders to .qsb"
	@echo "make clean           remove the build leftovers"

all: arch phone

arch:
	cd $(ARCH) && makepkg -f

arch-install:
	cd $(ARCH) && makepkg -fsi

arch-git:
	cd $(ARCH) && makepkg -f -p PKGBUILD-git

arch-git-install:
	cd $(ARCH) && makepkg -fsi -p PKGBUILD-git

phone:
	$(SAILFISH)

phone-install: need-phone
	$(SAILFISH) install $(PHONE)

test:
	tests/run.sh

phone-test: need-phone
	PLAY=1 tests/silica.sh $(PHONE) home AlbumsPage ArtistsPage PlaylistsPage FavoritesPage SettingsPage QueuePage NowPlayingPage LyricsPage
	NOBUILD=1 KEYBOARD=1 tests/silica.sh $(PHONE) SearchPage LoginDialog
	NOBUILD=1 PLAY=1 LANDSCAPE=1 tests/silica.sh $(PHONE) home NowPlayingPage LyricsPage

bench: need-phone
	PERF=1 PLAY=1 tests/silica.sh $(PHONE)

# The texts (qsTrId in QML, qtTrId in Go, //% for the English) into the .ts files: ryugin.ts
# the English, ryugin-<lang>.ts the translations; qm compiles them (main.go loads them).
# Qt 5's lupdate reads copies without the pragma it does not know, and only the Go files
# with texts (it reads them as C++).
ts:
	t=$$(mktemp -d) && for f in qml/*.qml qml-sailfish/*.qml qml-sailfish/*/*.qml app/*.go; do \
		mkdir -p "$$t/$${f%/*}" && sed '/^pragma ComponentBehavior/d' "$$f" > "$$t/$$f"; done && \
	(cd "$$t" && $(LUPDATE) -silent -no-obsolete -locations none qml qml-sailfish $$(grep -l 'qtTrId("' app/*.go) \
		-ts $(CURDIR)/qml/translations/ryugin.ts $(CURDIR)/qml/translations/ryugin-*.ts); s=$$?; rm -rf "$$t"; exit $$s

qm:
	$(LRELEASE) -silent qml/translations/ryugin-*.ts
	$(LRELEASE) -silent qml/translations/ryugin.ts -qm qml/translations/ryugin_eng_en.qm

# GLSL for desktop GL and for GLES (100 es, as Qt's own shaders, or GLES will not link our
# fragment shaders with Qt's vertex one), HLSL and MSL. flow has its own vertex shader and
# const arrays, which GLSL ES 1.00 lacks: 300 es too.
shaders:
	for f in qml/*.frag qml/*.vert; do g="100es,120,150"; case $$f in qml/flow.*) g="300es,$$g";; esac; \
		$(QSB) --glsl "$$g" --hlsl 50 --msl 12 -o "$$f.qsb" "$$f" || exit 1; done

clean:
	rm -rf $(ARCH)/src $(ARCH)/pkg $(ARCH)/ryugin .rpmbuild ryugin

need-phone:
	@[ -n "$(PHONE)" ] || { echo "set PHONE, e.g. make $(MAKECMDGOALS) PHONE=10.0.0.5" >&2; exit 1; }
