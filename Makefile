PACKAGE = gc
ORG = amylum

DEP_DIR = /tmp/dep-dir

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --infodir=/tmp/trash
CONF_FLAGS = --enable-cplusplus --with-pic
CFLAGS = -static -static-libgcc -Wl,-static -I$(DEP_DIR)/usr/include

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/gc//;s/_/./g')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

LIBATOMIC_OPS_VERSION = 7.4.2-1
LIBATOMIC_OPS_URL = https://github.com/amylum/libatomic_ops/releases/download/$(LIBATOMIC_OPS_VERSION)/libatomic_ops.tar.gz
LIBATOMIC_OPS_TAR = /tmp/libatomic_ops.tar.gz
LIBATOMIC_OPS_DIR = /tmp/libatomic_ops
LIBATOMIC_OPS_PATH = -I$(LIBATOMIC_OPS_DIR)/usr/include -L$(LIBATOMIC_OPS_DIR)/usr/lib

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(LIBATOMIC_OPS_DIR) $(LIBATOMIC_OPS_TAR)
	mkdir $(LIBATOMIC_OPS_DIR)
	curl -sLo $(LIBATOMIC_OPS_TAR) $(LIBATOMIC_OPS_URL)
	tar -x -C $(LIBATOMIC_OPS_DIR) -f $(LIBATOMIC_OPS_TAR)
	rm -rf $(DEP_DIR)
	mkdir -p $(DEP_DIR)/usr/include
	cp -R /usr/include/{linux,asm,asm-generic} $(DEP_DIR)/usr/include/

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && ./autogen.sh
	patch -d $(BUILD_DIR) -p1 < patches/noelision.patch
	patch -d $(BUILD_DIR) -p1 < patches/gc-7.4.2-Export-GC-push-all-eager.patch
	sed -i 's/#     include <asm\/sigcontext.h>//' $(BUILD_DIR)/os_dep.c
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(LIBATOMIC_OPS_PATH)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -rf $(RELEASE_DIR)/tmp
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/README.QUICK $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

