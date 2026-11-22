# Ryūgin's packages and checks. `make` lists the targets.
# Both packages build from this working tree (uncommitted changes included).
# PHONE: the Jolla phone's IP or name (SSH as defaultuser), e.g. `make phone-install PHONE=10.0.0.5`.
PHONE ?=

.PHONY: help all arch arch-install phone phone-install test bench shaders clean need-phone

help:
	@echo "make arch            Arch package (arch/*.pkg.tar.zst)"
	@echo "make arch-install    build and install it here"
	@echo "make phone           Sailfish OS package (RPMS/*.aarch64.rpm)"
	@echo "make phone-install   build and install it on PHONE"
	@echo "make all             both packages"
	@echo "make test            lint and every test (tests/run.sh)"
	@echo "make bench           bench on PHONE (tests/phone.sh)"
	@echo "make shaders         compile the shaders to .qsb"
	@echo "make clean           remove the build leftovers"

all: arch phone

arch:
	cd arch && makepkg -f

arch-install:
	cd arch && makepkg -fsi

phone:
	./sailfish.sh

phone-install: need-phone
	./sailfish.sh install $(PHONE)

test:
	tests/run.sh

bench: need-phone
	tests/phone.sh $(PHONE)

shaders:
	./shaders.sh

clean:
	rm -rf arch/src arch/pkg arch/ryugin .rpmbuild ryugin

need-phone:
	@[ -n "$(PHONE)" ] || { echo "set PHONE, e.g. make $(MAKECMDGOALS) PHONE=10.0.0.5" >&2; exit 1; }
