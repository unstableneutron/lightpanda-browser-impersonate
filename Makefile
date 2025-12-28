# Variables
# ---------

ZIG := zig
BC := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
# option test filter make test F="server"
F=
# Use curl-impersonate for TLS fingerprinting: USE_CURL_IMPERSONATE=1 make build
# Note: We use USE_CURL_IMPERSONATE (not CURL_IMPERSONATE) to avoid collision with
# curl-impersonate's runtime env var which expects an impersonation target string.
USE_CURL_IMPERSONATE ?= 0
ZIG_CURL_FLAG := $(if $(filter 1,$(USE_CURL_IMPERSONATE)),-Duse_curl_impersonate=true,)

# OS and ARCH
kernel = $(shell uname -ms)
ifeq ($(kernel), Darwin arm64)
	OS := macos
	ARCH := aarch64
else ifeq ($(kernel), Darwin x86_64)
	OS := macos
	ARCH := x86_64
else ifeq ($(kernel), Linux aarch64)
	OS := linux
	ARCH := aarch64
else ifeq ($(kernel), Linux arm64)
	OS := linux
	ARCH := aarch64
else ifeq ($(kernel), Linux x86_64)
	OS := linux
	ARCH := x86_64
else
	$(error "Unhandled kernel: $(kernel)")
endif


# Infos
# -----
.PHONY: help

## Display this help screen
help:
	@printf "\e[36m%-35s %s\e[0m\n" "Command" "Usage"
	@sed -n -e '/^## /{'\
		-e 's/## //g;'\
		-e 'h;'\
		-e 'n;'\
		-e 's/:.*//g;'\
		-e 'G;'\
		-e 's/\n/ /g;'\
		-e 'p;}' Makefile | awk '{printf "\033[33m%-35s\033[0m%s\n", $$1, substr($$0,length($$1)+1)}'


# $(ZIG) commands
# ------------
.PHONY: build build-dev run run-release shell test bench wpt data end2end

## Build in release-safe mode (use USE_CURL_IMPERSONATE=1 for TLS fingerprinting)
build:
	@printf "\e[36mBuilding (release safe$(if $(filter 1,$(USE_CURL_IMPERSONATE)), + curl-impersonate,))...\e[0m\n"
	$(ZIG) build -Doptimize=ReleaseSafe $(ZIG_CURL_FLAG) -Dgit_commit=$$(git rev-parse --short HEAD) || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mBuild OK\e[0m\n"

## Build in debug mode (use USE_CURL_IMPERSONATE=1 for TLS fingerprinting)
build-dev:
	@printf "\e[36mBuilding (debug$(if $(filter 1,$(USE_CURL_IMPERSONATE)), + curl-impersonate,))...\e[0m\n"
	@$(ZIG) build $(ZIG_CURL_FLAG) -Dgit_commit=$$(git rev-parse --short HEAD) || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mBuild OK\e[0m\n"

## Run the server in release mode
run: build
	@printf "\e[36mRunning...\e[0m\n"
	@./zig-out/bin/lightpanda || (printf "\e[33mRun ERROR\e[0m\n"; exit 1;)

## Run the server in debug mode
run-debug: build-dev
	@printf "\e[36mRunning...\e[0m\n"
	@./zig-out/bin/lightpanda || (printf "\e[33mRun ERROR\e[0m\n"; exit 1;)

## Run a JS shell in debug mode
shell:
	@printf "\e[36mBuilding shell...\e[0m\n"
	@$(ZIG) build shell || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)

## Run WPT tests
wpt:
	@printf "\e[36mBuilding wpt...\e[0m\n"
	@$(ZIG) build wpt -- $(filter-out $@,$(MAKECMDGOALS)) || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)

wpt-summary:
	@printf "\e[36mBuilding wpt...\e[0m\n"
	@$(ZIG) build wpt -- --summary $(filter-out $@,$(MAKECMDGOALS)) || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)

## Test - `grep` is used to filter out the huge compile command on build (use USE_CURL_IMPERSONATE=1 for TLS fingerprinting)
ifeq ($(OS), macos)
test:
	@script -q /dev/null sh -c 'TEST_FILTER="${F}" $(ZIG) build test $(ZIG_CURL_FLAG) -freference-trace --summary all' 2>&1 \
		| grep --line-buffered -v "^/.*zig test -freference-trace"
else
test:
	@script -qec 'TEST_FILTER="${F}" $(ZIG) build test $(ZIG_CURL_FLAG) -freference-trace --summary all' /dev/null 2>&1 \
		| grep --line-buffered -v "^/.*zig test -freference-trace"
endif

## Run demo/runner end to end tests
end2end:
	@test -d ../demo
	cd ../demo && go run runner/main.go

# Install and build required dependencies commands
# ------------
# Pattern: install-X tries download first, falls back to build
#          build-X always builds from source
.PHONY: install-submodule
.PHONY: install-v8 clean-v8
.PHONY: install-libiconv build-libiconv clean-libiconv
.PHONY: install-netsurf build-netsurf clean-netsurf test-netsurf
.PHONY: install-mimalloc build-mimalloc clean-mimalloc
.PHONY: install-curl-impersonate build-curl-impersonate clean-curl-impersonate
.PHONY: install-dev install

# Pre-built deps release URL (for download)
# DEPS_KEY is derived from the last commit that changed vendor/
DEPS_KEY := $(shell git log -1 --format=%h -- vendor/)
DEPS_RELEASE_URL := https://github.com/unstableneutron/lightpanda-browser-impersonate/releases/download/deps-$(OS)-$(ARCH)-$(DEPS_KEY)
DEPS_RELEASE_URL_ALIAS := https://github.com/unstableneutron/lightpanda-browser-impersonate/releases/download/deps-$(OS)-$(ARCH)

## Install and build dependencies for release
install: install-submodule install-v8 install-libiconv install-netsurf install-mimalloc install-curl-impersonate

## Install and build dependencies for dev
install-dev: install-submodule install-v8 install-libiconv install-netsurf-dev install-mimalloc-dev install-curl-impersonate

BC_NS := $(BC)vendor/netsurf/out/$(OS)-$(ARCH)
ICONV := $(BC)vendor/libiconv/out/$(OS)-$(ARCH)

# netsurf: install tries download, falls back to build
install-netsurf-dev: OPTCFLAGS := -O0 -g -DNDEBUG
install-netsurf-dev:
	@if [ -f "$(BC_NS)/lib/libdom.a" ]; then \
		printf "\e[33mnetsurf already installed at $(BC_NS)\e[0m\n"; \
	else \
		printf "\e[36mDownloading pre-built netsurf for $(OS)-$(ARCH)...\e[0m\n"; \
		mkdir -p $(BC_NS); \
		if curl -fL $(DEPS_RELEASE_URL)/netsurf.tar.gz | tar -xzf - -C $(BC_NS); then \
			printf "\e[33mDone netsurf $(OS)-$(ARCH) (versioned)\e[0m\n"; \
		elif curl -fL $(DEPS_RELEASE_URL_ALIAS)/netsurf.tar.gz | tar -xzf - -C $(BC_NS); then \
			printf "\e[33mDone netsurf $(OS)-$(ARCH) (alias)\e[0m\n"; \
		else \
			printf "\e[33mDownload failed, building from source...\e[0m\n"; \
			$(MAKE) build-netsurf-dev; \
		fi \
	fi

install-netsurf: OPTCFLAGS := -DNDEBUG
install-netsurf:
	@if [ -f "$(BC_NS)/lib/libdom.a" ]; then \
		printf "\e[33mnetsurf already installed at $(BC_NS)\e[0m\n"; \
	else \
		printf "\e[36mDownloading pre-built netsurf for $(OS)-$(ARCH)...\e[0m\n"; \
		mkdir -p $(BC_NS); \
		if curl -fL $(DEPS_RELEASE_URL)/netsurf.tar.gz | tar -xzf - -C $(BC_NS); then \
			printf "\e[33mDone netsurf $(OS)-$(ARCH) (versioned)\e[0m\n"; \
		elif curl -fL $(DEPS_RELEASE_URL_ALIAS)/netsurf.tar.gz | tar -xzf - -C $(BC_NS); then \
			printf "\e[33mDone netsurf $(OS)-$(ARCH) (alias)\e[0m\n"; \
		else \
			printf "\e[33mDownload failed, building from source...\e[0m\n"; \
			$(MAKE) build-netsurf; \
		fi \
	fi

build-netsurf-dev: OPTCFLAGS := -O0 -g -DNDEBUG
build-netsurf-dev: _build-netsurf

build-netsurf: OPTCFLAGS := -DNDEBUG
build-netsurf: _build-netsurf

_build-netsurf: clean-netsurf
	@printf "\e[36mInstalling NetSurf...\e[0m\n" && \
	ls $(ICONV)/lib/libiconv.a 1> /dev/null || (printf "\e[33mERROR: you need to execute 'make install-libiconv'\e[0m\n"; exit 1;) && \
	mkdir -p $(BC_NS) && \
	cp -R vendor/netsurf/share $(BC_NS) && \
	export PREFIX=$(BC_NS) && \
	export OPTLDFLAGS="-L$(ICONV)/lib" && \
	export OPTCFLAGS="$(OPTCFLAGS) -I$(ICONV)/include" && \
	printf "\e[33mInstalling libwapcaplet...\e[0m\n" && \
	cd vendor/netsurf/libwapcaplet && \
	BUILDDIR=$(BC_NS)/build/libwapcaplet make install && \
	cd ../libparserutils && \
	printf "\e[33mInstalling libparserutils...\e[0m\n" && \
	BUILDDIR=$(BC_NS)/build/libparserutils make install && \
	cd ../libhubbub && \
	printf "\e[33mInstalling libhubbub...\e[0m\n" && \
	BUILDDIR=$(BC_NS)/build/libhubbub make install && \
	rm src/treebuilder/autogenerated-element-type.c && \
	cd ../libdom && \
	printf "\e[33mInstalling libdom...\e[0m\n" && \
	BUILDDIR=$(BC_NS)/build/libdom make install && \
	printf "\e[33mRunning libdom example...\e[0m\n" && \
	cd examples && \
	$(ZIG) cc \
	-I$(ICONV)/include \
	-I$(BC_NS)/include \
	-L$(ICONV)/lib \
	-L$(BC_NS)/lib \
	-liconv \
	-ldom \
	-lhubbub \
	-lparserutils \
	-lwapcaplet \
	-o a.out \
	dom-structure-dump.c \
	$(ICONV)/lib/libiconv.a && \
	./a.out > /dev/null && \
	rm a.out && \
	printf "\e[36mDone NetSurf $(OS)\e[0m\n"

clean-netsurf:
	@printf "\e[36mCleaning NetSurf build...\e[0m\n" && \
	rm -Rf $(BC_NS)

test-netsurf:
	@printf "\e[36mTesting NetSurf...\e[0m\n" && \
	export PREFIX=$(BC_NS) && \
	export LDFLAGS="-L$(ICONV)/lib -L$(BC_NS)/lib" && \
	export CFLAGS="-I$(ICONV)/include -I$(BC_NS)/include" && \
	cd vendor/netsurf/libdom && \
	BUILDDIR=$(BC_NS)/build/libdom make test

# libiconv: install tries download pre-built, falls back to build
install-libiconv:
	@if [ -f "$(ICONV)/lib/libiconv.a" ]; then \
		printf "\e[33mlibiconv already installed at $(ICONV)\e[0m\n"; \
	else \
		printf "\e[36mDownloading pre-built libiconv for $(OS)-$(ARCH)...\e[0m\n"; \
		mkdir -p $(ICONV); \
		if curl -fL $(DEPS_RELEASE_URL)/libiconv.tar.gz | tar -xzf - -C $(ICONV); then \
			printf "\e[33mDone libiconv $(OS)-$(ARCH) (versioned)\e[0m\n"; \
		elif curl -fL $(DEPS_RELEASE_URL_ALIAS)/libiconv.tar.gz | tar -xzf - -C $(ICONV); then \
			printf "\e[33mDone libiconv $(OS)-$(ARCH) (alias)\e[0m\n"; \
		else \
			printf "\e[33mDownload failed, building from source...\e[0m\n"; \
			$(MAKE) build-libiconv; \
		fi \
	fi

build-libiconv: _download-libiconv-src clean-libiconv
	@printf "\e[36mBuilding libiconv from source...\e[0m\n"
	@cd vendor/libiconv/libiconv-1.17 && \
	./configure --prefix=$(ICONV) --enable-static && \
	make && make install
	@printf "\e[33mDone libiconv $(OS)-$(ARCH)\e[0m\n"

_download-libiconv-src:
ifeq ("$(wildcard vendor/libiconv/libiconv-1.17)","")
	@mkdir -p vendor/libiconv
	@cd vendor/libiconv && \
	curl -L https://github.com/lightpanda-io/libiconv/releases/download/1.17/libiconv-1.17.tar.gz | tar -xvzf -
endif

clean-libiconv:
ifneq ("$(wildcard vendor/libiconv/libiconv-1.17/Makefile)","")
	@cd vendor/libiconv/libiconv-1.17 && \
	make clean
endif

data:
	cd src/data && go run public_suffix_list_gen.go > public_suffix_list.zig

# mimalloc: install tries download, falls back to build
MIMALLOC := $(BC)vendor/mimalloc/out/$(OS)-$(ARCH)

install-mimalloc-dev:
	@if [ -f "$(MIMALLOC)/lib/libmimalloc.a" ]; then \
		printf "\e[33mmimalloc already installed at $(MIMALLOC)\e[0m\n"; \
	else \
		printf "\e[36mDownloading pre-built mimalloc for $(OS)-$(ARCH)...\e[0m\n"; \
		mkdir -p $(MIMALLOC); \
		if curl -fL $(DEPS_RELEASE_URL)/mimalloc.tar.gz | tar -xzf - -C $(MIMALLOC); then \
			printf "\e[33mDone mimalloc $(OS)-$(ARCH) (versioned)\e[0m\n"; \
		elif curl -fL $(DEPS_RELEASE_URL_ALIAS)/mimalloc.tar.gz | tar -xzf - -C $(MIMALLOC); then \
			printf "\e[33mDone mimalloc $(OS)-$(ARCH) (alias)\e[0m\n"; \
		else \
			printf "\e[33mDownload failed, building from source...\e[0m\n"; \
			$(MAKE) build-mimalloc-dev; \
		fi \
	fi

install-mimalloc:
	@if [ -f "$(MIMALLOC)/lib/libmimalloc.a" ]; then \
		printf "\e[33mmimalloc already installed at $(MIMALLOC)\e[0m\n"; \
	else \
		printf "\e[36mDownloading pre-built mimalloc for $(OS)-$(ARCH)...\e[0m\n"; \
		mkdir -p $(MIMALLOC); \
		if curl -fL $(DEPS_RELEASE_URL)/mimalloc.tar.gz | tar -xzf - -C $(MIMALLOC); then \
			printf "\e[33mDone mimalloc $(OS)-$(ARCH) (versioned)\e[0m\n"; \
		elif curl -fL $(DEPS_RELEASE_URL_ALIAS)/mimalloc.tar.gz | tar -xzf - -C $(MIMALLOC); then \
			printf "\e[33mDone mimalloc $(OS)-$(ARCH) (alias)\e[0m\n"; \
		else \
			printf "\e[33mDownload failed, building from source...\e[0m\n"; \
			$(MAKE) build-mimalloc; \
		fi \
	fi

build-mimalloc-dev: OPTS=-DCMAKE_BUILD_TYPE=Debug
build-mimalloc-dev: _build-mimalloc
	@cd $(MIMALLOC) && \
	mv build/libmimalloc-debug.a lib/libmimalloc.a

build-mimalloc: _build-mimalloc
	@cd $(MIMALLOC) && \
	mv build/libmimalloc.a lib/libmimalloc.a

_build-mimalloc: clean-mimalloc
	@printf "\e[36mBuilding mimalloc from source...\e[0m\n"
	@mkdir -p $(MIMALLOC)/build && \
	cd $(MIMALLOC)/build && \
	cmake -DMI_BUILD_SHARED=OFF -DMI_BUILD_OBJECT=OFF -DMI_BUILD_TESTS=OFF -DMI_OVERRIDE=OFF $(OPTS) ../../.. && \
	make && \
	mkdir -p $(MIMALLOC)/lib

clean-mimalloc:
	@rm -Rf $(MIMALLOC)/build

## Init and update git submodule
install-submodule:
	@git submodule init && \
	git submodule update

# v8 (pre-built from zig-v8-fork)
# -------------------------------
V8_VERSION := 14.0.365.4
ZIG_V8_VERSION := v0.1.35
V8_RELEASE_URL := https://github.com/lightpanda-io/zig-v8-fork/releases/download/$(ZIG_V8_VERSION)

install-v8:
	@if [ -f "v8/libc_v8.a" ]; then \
		printf "\e[33mv8 already installed\e[0m\n"; \
	else \
		printf "\e[36mDownloading v8 $(V8_VERSION) for $(OS)-$(ARCH)...\e[0m\n"; \
		mkdir -p v8; \
		curl -fL $(V8_RELEASE_URL)/libc_v8_$(V8_VERSION)_$(OS)_$(ARCH).a -o v8/libc_v8.a || \
			(printf "\e[31mFailed to download v8\e[0m\n"; exit 1); \
		printf "\e[33mDone v8\e[0m\n"; \
	fi

clean-v8:
	@rm -rf v8

# curl-impersonate (for TLS fingerprinting)
# -----------------------------------------
CURL_IMP := $(BC)vendor/curl-impersonate/out/$(OS)-$(ARCH)
CURL_IMP_BUILD := $(BC)vendor/curl-impersonate/build
CURL_IMP_RELEASE_URL := $(DEPS_RELEASE_URL)

## Install curl-impersonate: tries download, falls back to build
install-curl-impersonate:
	@if [ -f "$(CURL_IMP)/lib/libcurl-impersonate.a" ]; then \
		printf "\e[33mcurl-impersonate already installed at $(CURL_IMP)\e[0m\n"; \
	else \
		printf "\e[36mDownloading pre-built curl-impersonate for $(OS)-$(ARCH)...\e[0m\n"; \
		mkdir -p $(CURL_IMP); \
		if curl -fL $(DEPS_RELEASE_URL)/curl-impersonate.tar.gz | tar -xzf - -C $(CURL_IMP); then \
			printf "\e[33mDone curl-impersonate $(OS)-$(ARCH) (versioned)\e[0m\n"; \
		elif curl -fL $(DEPS_RELEASE_URL_ALIAS)/curl-impersonate.tar.gz | tar -xzf - -C $(CURL_IMP); then \
			printf "\e[33mDone curl-impersonate $(OS)-$(ARCH) (alias)\e[0m\n"; \
		else \
			printf "\e[33mDownload failed, building from source...\e[0m\n"; \
			$(MAKE) build-curl-impersonate; \
		fi \
	fi

## Build curl-impersonate from source (requires cmake, ninja, go, autotools, zstd)
build-curl-impersonate: clean-curl-impersonate
	@printf "\e[36mBuilding curl-impersonate (this may take 5-10 minutes)...\e[0m\n"
	@mkdir -p $(CURL_IMP_BUILD)
ifeq ($(OS), macos)
	@cd $(CURL_IMP_BUILD) && \
		CPPFLAGS="-I/opt/homebrew/opt/zstd/include" \
		LDFLAGS="-L/opt/homebrew/opt/zstd/lib" \
		../configure --prefix=$(CURL_IMP) --enable-static
	@cd $(CURL_IMP_BUILD) && gmake build
else
	@cd $(CURL_IMP_BUILD) && \
		../configure --prefix=$(CURL_IMP) --enable-static
	@cd $(CURL_IMP_BUILD) && make build
endif
	@mkdir -p $(CURL_IMP)/lib $(CURL_IMP)/include
	@cp $(CURL_IMP_BUILD)/curl-*/lib/.libs/libcurl-impersonate.a $(CURL_IMP)/lib/ 2>/dev/null || \
		cp $(CURL_IMP_BUILD)/curl-*/src/.libs/libcurl-impersonate.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/boringssl-*/lib/libssl.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/boringssl-*/lib/libcrypto.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/nghttp2-*/installed/lib/libnghttp2.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/ngtcp2-*/installed/lib/libngtcp2.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/ngtcp2-*/installed/lib/libngtcp2_crypto_boringssl.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/nghttp3-*/installed/lib/libnghttp3.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/c-ares-*/installed/lib/libcares.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/brotli-*/out/installed/lib/libbrotlidec.a $(CURL_IMP)/lib/
	@cp $(CURL_IMP_BUILD)/brotli-*/out/installed/lib/libbrotlicommon.a $(CURL_IMP)/lib/
	@cp -r $(CURL_IMP_BUILD)/curl-*/include/curl $(CURL_IMP)/include/
	@cp -r $(CURL_IMP_BUILD)/boringssl-*/include/openssl $(CURL_IMP)/include/
	@printf "\e[33mDone curl-impersonate $(OS)-$(ARCH)\e[0m\n"

clean-curl-impersonate:
	@printf "\e[36mCleaning curl-impersonate build...\e[0m\n" && \
	rm -Rf $(CURL_IMP_BUILD) $(CURL_IMP)

# Docker
# ------
.PHONY: docker docker-impersonate docker-all

DOCKER_IMAGE := lightpanda/browser
DOCKER_TAG := local

## Build standard Docker image (no TLS fingerprinting)
docker:
	@printf "\e[36mBuilding Docker image (standard)...\e[0m\n"
	docker build --build-arg GIT_COMMIT=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) .

## Build Docker image with curl-impersonate (TLS fingerprinting enabled)
docker-impersonate:
	@printf "\e[36mBuilding Docker image with curl-impersonate (this may take 15-20 minutes)...\e[0m\n"
	docker build --build-arg USE_CURL_IMPERSONATE=1 \
		--build-arg GIT_COMMIT=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG)-impersonate .

## Build both Docker images
docker-all: docker docker-impersonate
	@printf "\e[33mDone building all Docker images\e[0m\n"
