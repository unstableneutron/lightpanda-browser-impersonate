# Multi-stage Docker build for Lightpanda browser
# Supports optional curl-impersonate for TLS fingerprinting

# Build args
ARG USE_CURL_IMPERSONATE=0
ARG MINISIG=0.12
ARG ZIG_MINISIG=RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U
ARG V8=14.0.365.4
ARG ZIG_V8=v0.1.34

# ==============================================================================
# Stage: curl-impersonate-builder
# Builds curl-impersonate with patched BoringSSL for TLS fingerprinting
# ==============================================================================
FROM debian:stable-slim AS curl-impersonate-builder

ARG TARGETPLATFORM
ARG USE_CURL_IMPERSONATE

# Only build if USE_CURL_IMPERSONATE is enabled
RUN if [ "$USE_CURL_IMPERSONATE" = "0" ]; then \
        echo "Skipping curl-impersonate build" && \
        mkdir -p /out/lib /out/include && \
        exit 0; \
    fi && \
    apt-get update && \
    apt-get install -y \
        git ninja-build cmake autoconf automake pkg-config libtool \
        clang llvm lld libc++-dev libc++abi-dev \
        ca-certificates curl \
        zlib1g-dev libzstd-dev libidn2-dev libldap-dev \
        golang-go bzip2 xz-utils unzip make

WORKDIR /build

# Clone curl-impersonate (or copy from submodule if using local build)
RUN if [ "$USE_CURL_IMPERSONATE" = "1" ]; then \
        git clone --depth 1 https://github.com/lexiforest/curl-impersonate.git . ; \
    fi

ENV CC=clang CXX=clang++

# Build curl-impersonate (static libraries only)
RUN if [ "$USE_CURL_IMPERSONATE" = "1" ]; then \
        mkdir -p /build/build /out/lib /out/include && \
        cd /build/build && \
        ../configure --prefix=/out --enable-static \
            --with-zlib --with-zstd \
            --with-ca-path=/etc/ssl/certs \
            --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
        make build && \
        # Copy static libraries to output directory
        cp /build/build/curl-*/lib/.libs/libcurl-impersonate.a /out/lib/ 2>/dev/null || \
            cp /build/build/curl-*/src/.libs/libcurl-impersonate.a /out/lib/ && \
        cp /build/build/boringssl-*/lib/libssl.a /out/lib/ && \
        cp /build/build/boringssl-*/lib/libcrypto.a /out/lib/ && \
        cp /build/build/nghttp2-*/installed/lib/libnghttp2.a /out/lib/ && \
        cp /build/build/ngtcp2-*/installed/lib/libngtcp2.a /out/lib/ && \
        cp /build/build/ngtcp2-*/installed/lib/libngtcp2_crypto_boringssl.a /out/lib/ && \
        cp /build/build/nghttp3-*/installed/lib/libnghttp3.a /out/lib/ && \
        cp /build/build/c-ares-*/installed/lib/libcares.a /out/lib/ && \
        cp /build/build/brotli-*/out/installed/lib/libbrotlidec.a /out/lib/ && \
        cp /build/build/brotli-*/out/installed/lib/libbrotlicommon.a /out/lib/ && \
        # Copy headers
        cp -r /build/build/curl-*/include/curl /out/include/ && \
        cp -r /build/build/boringssl-*/include/openssl /out/include/ ; \
    else \
        mkdir -p /out/lib /out/include ; \
    fi

# ==============================================================================
# Stage: lightpanda-builder
# Builds the Lightpanda browser binary
# ==============================================================================
FROM debian:stable-slim AS lightpanda-builder

ARG MINISIG
ARG ZIG_MINISIG
ARG V8
ARG ZIG_V8
ARG TARGETPLATFORM
ARG USE_CURL_IMPERSONATE

RUN apt-get update -yq && \
    apt-get install -yq xz-utils \
        python3 ca-certificates git \
        pkg-config libglib2.0-dev \
        gperf libexpat1-dev \
        cmake clang \
        curl git \
        # Additional deps for curl-impersonate linking
        zlib1g-dev libzstd-dev libidn2-dev libldap-dev

# Install minisig
RUN curl --fail -L -O https://github.com/jedisct1/minisign/releases/download/${MINISIG}/minisign-${MINISIG}-linux.tar.gz && \
    tar xvzf minisign-${MINISIG}-linux.tar.gz -C /

# Copy local source files (excluding .git and build artifacts via .dockerignore)
WORKDIR /browser
COPY build.zig build.zig.zon Makefile ./
COPY src/ src/
COPY vendor/ vendor/
COPY tests/ tests/

# Install zig
RUN ZIG=$(grep '\.minimum_zig_version = "' "build.zig.zon" | cut -d'"' -f2) && \
    case $TARGETPLATFORM in \
      "linux/arm64") ARCH="aarch64" ;; \
      *) ARCH="x86_64" ;; \
    esac && \
    curl --fail -L -O https://ziglang.org/download/${ZIG}/zig-${ARCH}-linux-${ZIG}.tar.xz && \
    curl --fail -L -O https://ziglang.org/download/${ZIG}/zig-${ARCH}-linux-${ZIG}.tar.xz.minisig && \
    /minisign-linux/${ARCH}/minisign -Vm zig-${ARCH}-linux-${ZIG}.tar.xz -P ${ZIG_MINISIG} && \
    tar xvf zig-${ARCH}-linux-${ZIG}.tar.xz && \
    mv zig-${ARCH}-linux-${ZIG} /usr/local/lib && \
    ln -s /usr/local/lib/zig-${ARCH}-linux-${ZIG}/zig /usr/local/bin/zig

# Install deps (vendor dirs already copied)
RUN make install-libiconv && \
    make install-netsurf && \
    make install-mimalloc

# Download and install v8
RUN case $TARGETPLATFORM in \
    "linux/arm64") ARCH="aarch64" ;; \
    *) ARCH="x86_64" ;; \
    esac && \
    curl --fail -L -o libc_v8.a https://github.com/lightpanda-io/zig-v8-fork/releases/download/${ZIG_V8}/libc_v8_${V8}_linux_${ARCH}.a && \
    mkdir -p v8/ && \
    mv libc_v8.a v8/libc_v8.a

# Copy curl-impersonate artifacts if enabled
COPY --from=curl-impersonate-builder /out /curl-impersonate-out

# Set up curl-impersonate libs in the expected location
RUN case $TARGETPLATFORM in \
        "linux/arm64") ARCH="aarch64" ;; \
        *) ARCH="x86_64" ;; \
    esac && \
    if [ "$USE_CURL_IMPERSONATE" = "1" ]; then \
        mkdir -p vendor/curl-impersonate/out/linux-${ARCH}/lib && \
        mkdir -p vendor/curl-impersonate/out/linux-${ARCH}/include && \
        cp -r /curl-impersonate-out/lib/* vendor/curl-impersonate/out/linux-${ARCH}/lib/ && \
        cp -r /curl-impersonate-out/include/* vendor/curl-impersonate/out/linux-${ARCH}/include/ ; \
    fi

# Build release (with or without curl-impersonate)
ARG GIT_COMMIT=unknown
RUN if [ "$USE_CURL_IMPERSONATE" = "1" ]; then \
        zig build -Doptimize=ReleaseSafe -Dprebuilt_v8_path=v8/libc_v8.a -Duse_curl_impersonate=true -Dgit_commit="$GIT_COMMIT" ; \
    else \
        zig build -Doptimize=ReleaseSafe -Dprebuilt_v8_path=v8/libc_v8.a -Dgit_commit="$GIT_COMMIT" ; \
    fi

# ==============================================================================
# Stage: tini
# Get tini for proper signal handling
# ==============================================================================
FROM debian:stable-slim AS tini

RUN apt-get update -yq && \
    apt-get install -yq tini

# ==============================================================================
# Stage: runtime
# Final minimal runtime image
# ==============================================================================
FROM debian:stable-slim

# Install runtime dependencies for curl-impersonate build
# (libidn2, zlib, zstd, ldap are dynamically linked)
RUN apt-get update -yq && \
    apt-get install -yq --no-install-recommends \
        libidn2-0 \
        zlib1g \
        libzstd1 \
        libldap2 \
    && rm -rf /var/lib/apt/lists/*

# Copy ca certificates
COPY --from=lightpanda-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=lightpanda-builder /browser/zig-out/bin/lightpanda /bin/lightpanda
COPY --from=tini /usr/bin/tini /usr/bin/tini

EXPOSE 9222/tcp

# Lightpanda installs only some signal handlers, and PID 1 doesn't have a default SIGTERM signal handler.
# Using "tini" as PID1 ensures that signals work as expected, so e.g. "docker stop" will not hang.
# (See https://github.com/krallin/tini#why-tini).
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/lightpanda", "serve", "--host", "0.0.0.0", "--port", "9222", "--log_level", "info"]
