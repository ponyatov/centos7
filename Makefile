# \ var
# detect module/project name by current directory
MODULE  = $(notdir $(CURDIR))
# detect OS name (only Linux/MinGW)
OS      = $(shell uname -s)
# host machine architecture (for cross-compiling)
MACHINE = $(shell uname -m)
# current date in the `ddmmyy` format
NOW     = $(shell date +%d%m%y)
# release hash: four hex digits (for snapshots)
REL     = $(shell git rev-parse --short=4 HEAD)
# current git branch
BRANCH  = $(shell git rev-parse --abbrev-ref HEAD)
# your own private working branch name
SHADOW ?= ponymuck
# number of CPU cores (for parallel builds)
CORES   = $(shell grep processor /proc/cpuinfo| wc -l)
AUTHOR  = "Dmitry Ponyatov"
EMAIL   = "dponyatov@gmail.com"
# / var

# \ dir
# current (project) directory
CWD     = $(CURDIR)
# compiled/executable files (target dir)
BIN     = $(CWD)/bin
# documentation & external manuals download
DOC     = $(CWD)/doc
# libraries / scripts
LIB     = $(CWD)/lib
# source code (not for all languages, Rust/C/Java included)
SRC     = $(CWD)/src
# temporary/flags/generated files
TMP     = $(CWD)/tmp
FW      = $(CWD)/firmware
GZ      = $(CWD)/gz
# / dir

# \ tool
# http/ftp download
CURL    = curl -L -o
PY      = $(shell which python3)
PIP     = $(shell which pip3)
PEP     = $(shell which autopep8)
PYT     = $(shell which pytest)
# / tool

# \ src
Y   += $(MODULE).metaL.py metaL.py
S   += $(Y)
# / src

# \ package
CENTOS_BUILD  = 2009
CENTOS_VER    = 7.9.$(CENTOS_BUILD)
CENTOS_MIRROR = https://mirror.yandex.ru/centos/$(CENTOS_VER)/isos/x86_64
CENTOS        = CentOS-7-x86_64

NETINST       = $(CENTOS)-NetInstall-$(CENTOS_BUILD)
NETINST_ISO   = $(NETINST).iso
NETINST_TORR  = $(NETINST).torrent
NETINST_URL   = $(CENTOS_MIRROR)/$(NETINST_TORR)

MINIMAL       = $(CENTOS)-Minimal-$(CENTOS_BUILD)
MINIMAL_ISO   = $(MINIMAL).iso
MINIMAL_TORR  = $(MINIMAL).torrent
MINIMAL_URL   = $(CENTOS_MIRROR)/$(MINIMAL_TORR)

SYSLINUX_VER  = 6.03
SYSLINUX      = syslinux-$(SYSLINUX_VER)
SYSLINUX_GZ   = $(SYSLINUX).tar.gz
SYSLINUX_URL  = https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/$(SYSLINUX_GZ)
# / package

# \ all

RPMS = $(shell find tmp/cdrom/Packages -type f      -regex ".+.rpm$$" | sed "s/tmp\/cdrom/kickstart/g")
REPO = $(shell find tmp/cdrom/repodata -type f -not -regex ".+.TBL$$" | sed "s/tmp\/cdrom/kickstart/g")
EFI += $(shell find tmp/cdrom/EFI -type f -regex ".+.efi$$" | sed "s/tmp\/cdrom/kickstart/g")
EFI += $(shell find tmp/cdrom/EFI -type f -regex ".+.EFI$$" | sed "s/tmp\/cdrom/kickstart/g")
EFI += $(shell find tmp/cdrom/EFI -type f -regex ".+.pf2$$" | sed "s/tmp\/cdrom/kickstart/g")

.PHONY: all
all: syslinux \
	kickstart/isolinux/isolinux.bin kickstart/isolinux/vesamenu.c32 \
	kickstart/isolinux/vmlinuz kickstart/LiveOS/squashfs.img \
	kickstart/images/pxeboot/vmlinuz kickstart/images/pxeboot/initrd.img \
	kickstart/images/efiboot.img \
	kickstart/.discinfo kickstart/.treeinfo \
	$(RPMS) $(REPO) $(EFI)
#	kickstart/isolinux/menu.c32 kickstart/isolinux/vesamenu.c32 \
#	kickstart/isolinux/libutil.c32 kickstart/isolinux/libcom32.c32 \
#	kickstart/isolinux/ldlinux.c32 \

kickstart/isolinux/vmlinuz: tmp/cdrom/isolinux/vmlinuz
	cp tmp/cdrom/isolinux/* kickstart/isolinux/

# kickstart/isolinux/isolinux.bin: $(TMP)/$(SYSLINUX)/bios/core/isolinux.bin
# 	cp $< $@

xxx:
	rm -rf iso/*
	cp -r tmp/cdrom/* iso/
	chmod -R u+w iso
oem:
	genisoimage \
		-untranslated-filenames -volid 'OEM' \
		-J -joliet-long -rational-rock -translation-table \
		-input-charset utf-8 -x ./lost+found -x TRANS.TBL \
		-b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-eltorito-alt-boot -eltorito-boot images/efiboot.img -no-emul-boot \
		-o firmware/centos7.iso -T iso/
#		isohybrid -u $src_iso
#		-untranslated-filenames -volid 'CentOS 7 x86_64' \

.PHONY: iso
iso: $(FW)/$(MODULE).iso
$(FW)/$(MODULE).iso: $(shell find kickstart -type f) Makefile
	xorriso -as mkisofs \
		-b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-R -J -v -V 'CentOS 7 x86_64' -o $@ tmp/cdrom

#		-isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin \

.PHONY: qemu
qemu: $(FW)/$(MODULE).iso
	qemu-system-x86_64 -m 1G -cdrom $< -boot menu=on

.PHONY: meta
meta: $(PY) $(MODULE).metaL.py
	$^
	$(MAKE) format_py

format_py: tmp/format_py
tmp/format_py: $(Y)
	$(PEP) --ignore=E26,E302,E305,E401,E402,E701,E702 --in-place $?
	touch $@

.PHONY: syslinux
syslinux: $(TMP)/$(SYSLINUX)/version.mk
$(TMP)/$(SYSLINUX)/version.mk: $(SRC)/$(SYSLINUX)/README
	rm -rf $(TMP)/$(SYSLINUX) ; mkdir -p $(TMP)/$(SYSLINUX)
	cd $(SRC)/$(SYSLINUX) ; make -j$(CORES) clean ;\
	make -j$(CORES) O=$(TMP)/$(SYSLINUX) bios
# / all

# \ rule
$(SRC)/%/README: $(GZ)/%.tar.gz
	cd src ;  zcat $< | tar x && touch $@
$(SRC)/%/README: $(GZ)/%.tar.xz
	cd src ; xzcat $< | tar x && touch $@

kickstart/%: tmp/cdrom/%
	cp $< $@

COM32 = $(TMP)/$(SYSLINUX)/bios/com32
# kickstart/isolinux/%: $(COM32)/menu/%
# 	cp $< $@
kickstart/isolinux/%: $(COM32)/libutil/%
	cp $< $@
kickstart/isolinux/%: $(COM32)/lib/%
	cp $< $@
kickstart/isolinux/%: $(COM32)/elflink/ldlinux/%
	cp $< $@
# / rule

# \ doc

.PHONY: doxy
doxy:
	rm -rf docs ; doxygen doxy.gen 1>/dev/null

.PHONY: doc
doc:
# / doc

# \ install
.PHONY: install update
install: $(OS)_install doc gz
	$(MAKE) update
update: $(OS)_update
	$(PIP) install --user -U pip pytest autopep8

.PHONY: Linux_install Linux_update
Linux_install Linux_update:
ifneq (,$(shell which apt))
	sudo apt update
	sudo apt install -u `cat apt.txt apt.dev`
endif

.PHONY: Msys_install Msys_update
Msys_install:
	pacman -S git make python3 python3-pip
Msys_update:

# \ gz
.PHONY: gz
gz: $(GZ)/$(NETINST_TORR) $(GZ)/$(MINIMAL_TORR) $(GZ)/$(SYSLINUX_GZ)

$(GZ)/$(NETINST_TORR):
	$(CURL) $@ $(NETINST_URL)
$(GZ)/$(MINIMAL_TORR):
	$(CURL) $@ $(MINIMAL_URL)

$(GZ)/$(SYSLINUX_GZ):
	$(CURL) $@ $(SYSLINUX_URL)
# / gz

mounts: gz/$(MINIMAL)/$(MINIMAL_ISO)
	mount $< tmp/cdrom
#	mount tmp/cdrom/LiveOS/squashfs.img tmp/cdrom/LiveOS
#	mount tmp/cdrom/LiveOS/LiveOS/rootfs.img tmp/cdrom/LiveOS
# / install

# \ merge
MERGE  = Makefile README.md .gitignore apt.dev apt.txt apt.msys doxy.gen $(S)
MERGE += .vscode bin doc lib src tmp

.PHONY: shadow
shadow:
	git push -v
	git checkout $@
	git pull -v

.PHONY: dev
dev:
	git push -v
	git checkout $@
	git pull -v
	git checkout $(SHADOW) -- $(MERGE)
	$(MAKE) doxy ; git add -f docs

.PHONY: release
release:
	git tag $(NOW)-$(REL)
	git push -v --tags
	$(MAKE) shadow

.PHONY: zip
ZIP = $(TMP)/$(MODULE)_$(BRANCH)_$(NOW)_$(REL).src.zip
zip:
	git archive --format zip --output $(ZIP) HEAD
	$(MAKE) doxy ; zip -r $(ZIP) docs
# / merge
