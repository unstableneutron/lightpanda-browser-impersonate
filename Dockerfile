# Multi-stage Docker build for Lightpanda browser
# Supports optional curl-impersonate for TLS fingerprinting

# Build args
ARG USE_CURL_IMPERSONATE=0
ARG MINISIG=0.12
ARG ZIG_MINISIG=RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U
ARG V8=14.0.365.4
ARG ZIG_V8=v0.1.34

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
        curl git make \
        # Additional deps for curl-impersonate linking
        zlib1g-dev libzstd-dev libidn2-dev libldap-dev

# Install minisig
RUN curl --fail -L -O https://github.com/jedisct1/minisign/releases/download/${MINISIG}/minisign-${MINISIG}-linux.tar.gz && \
    tar xvzf minisign-${MINISIG}-linux.tar.gz -C /

WORKDIR /browser

# Copy only build files and vendor first (for better layer caching)
COPY Makefile build.zig build.zig.zon ./
COPY vendor/ vendor/

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
    make install-mimalloc && \
    if [ "$USE_CURL_IMPERSONATE" = "1" ]; then make install-curl-impersonate; fi

# Download and install v8
RUN case $TARGETPLATFORM in \
    "linux/arm64") ARCH="aarch64" ;; \
    *) ARCH="x86_64" ;; \
    esac && \
    curl --fail -L -o libc_v8.a https://github.com/lightpanda-io/zig-v8-fork/releases/download/${ZIG_V8}/libc_v8_${V8}_linux_${ARCH}.a && \
    mkdir -p v8/ && \
    mv libc_v8.a v8/libc_v8.a

# Copy source files (after deps for better caching)
COPY src/ src/
COPY tests/ tests/

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
