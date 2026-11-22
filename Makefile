# Ryūgin's packages and checks. `make` lists the targets.
# Both packages build from this working tree (uncommitted changes included).
# PHONE: the Jolla phone's IP or name (SSH as defaultuser), e.g. `make phone-install PHONE=10.0.0.5`.
# QSB: Qt's shader compiler; use the one of the Qt that runs the app (an older Qt cannot
# read a newer .qsb).
PHONE ?=
QSB ?= /usr/lib/qt6/bin/qsb
ARCH = packaging/arch
SAILFISH = packaging/sailfish/build.sh

.PHONY: help all arch arch-install phone phone-install test bench shaders clean need-phone

help:
	@echo "make arch            Arch package ($(ARCH)/*.pkg.tar.zst)"
	@echo "make arch-install    build and install it here"
	@echo "make phone           Sailfish OS package (RPMS/*.aarch64.rpm)"
	@echo "make phone-install   build and install it on PHONE"
	@echo "make all             both packages"
	@echo "make test            lint and every test (tests/run.sh)"
	@echo "make bench           bench on PHONE (tests/phone.sh)"
	@echo "make shaders         compile qml/ shaders to .qsb"
	@echo "make clean           remove the build leftovers"

all: arch phone

arch:
	cd $(ARCH) && makepkg -f

arch-install:
	cd $(ARCH) && makepkg -fsi

phone:
	$(SAILFISH)

phone-install: need-phone
	$(SAILFISH) install $(PHONE)

test:
	tests/run.sh

bench: need-phone
	tests/phone.sh $(PHONE)

# GLSL for desktop GL and for GLES (phones: 100 es, as Qt's own shaders, or GLES will not
# link ours with them), HLSL and MSL.
shaders:
	for f in qml/*.frag qml/*.vert; do $(QSB) --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$$f.qsb" "$$f" || exit 1; done

clean:
	rm -rf $(ARCH)/src $(ARCH)/pkg $(ARCH)/ryugin .rpmbuild ryugin

need-phone:
	@[ -n "$(PHONE)" ] || { echo "set PHONE, e.g. make $(MAKECMDGOALS) PHONE=10.0.0.5" >&2; exit 1; }
