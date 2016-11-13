FROM ubuntu:xenial

ENV LUA_SANDBOX_REF            5e9818a66fa9756ebcfa934f3037d9545c191380
ENV LUA_SANDBOX_EXTENSIONS_REF a27759cc316000af6ca4c05a998bfcb79d0ec480
ENV HINDSIGHT_REF              6e5f63e7ffcc7eafb94a6f956d05c1453558f47d

ENV BUILD_DIR /build
ARG MAKE_FLAGS="-j4"

ENV LUA_SANDBOX_REQUIRED_BUILD_PKGS gcc g++ make cmake git ca-certificates lua5.1-dev
ENV LUA_SANDBOX_OPTIONAL_BUILD_PKGS libssl-dev zlib1g-dev libgeoip-dev libsystemd-dev
ENV BUILD_PKGS $LUA_SANDBOX_REQUIRED_BUILD_PKGS $LUA_SANDBOX_OPTIONAL_BUILD_PKGS

RUN apt-get update \
    # Build dependencies
    && apt-get install --no-install-recommends -y \
        $BUILD_PKGS \
    # Runtime dependencies
    && apt-get install --no-install-recommends -y \
        # libstdc++: rapidjson
        libstdc++6 \
        # systemd extension
        libsystemd0 \
    && mkdir $BUILD_DIR \
    && cd $BUILD_DIR \
    # Clone repos.
    && git clone https://github.com/mozilla-services/lua_sandbox \
    && git clone https://github.com/mozilla-services/lua_sandbox_extensions \
    && git clone https://github.com/trink/hindsight \
    # lua_sandbox
    && cd $BUILD_DIR/lua_sandbox \
    && git checkout "$LUA_SANDBOX_REF" \
    && mkdir release \
    && cd release \
    && cmake -DCMAKE_BUILD_TYPE=release -DCMAKE_INSTALL_PREFIX:PATH=/usr .. \
    && make $MAKE_FLAGS \
    && make install \
    # lua_sandbox_extensions
    && cd $BUILD_DIR/lua_sandbox_extensions \
    && git checkout "$LUA_SANDBOX_EXTENSIONS_REF" \
    && mkdir release \
    && cd release \
    && cmake \
        -DCMAKE_BUILD_TYPE=release \
        -DENABLE_ALL_EXT=true \
        -DCPACK_GENERATOR=TGZ \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        # Disable some extensions for now that require external libs.
        # TODO: Add libs for these.
        -DEXT_kafka=off \
        -DEXT_postgres=off \
        -DEXT_snappy=off \
         .. \
    && make $MAKE_FLAGS \
    # -DCMAKE_INSTALL_PREFIX=/usr wasn't being honored...use DESTDIR instead.
    && DESTDIR=/usr make install \
    # hindsight
    && cd $BUILD_DIR/hindsight \
    && git checkout "$HINDSIGHT_REF" \
    && mkdir release \
    && cd release \
    && cmake -DCMAKE_BUILD_TYPE=release -DCMAKE_INSTALL_PREFIX:PATH=/usr -DLIB_SUFFIX="" .. \
    && make $MAKE_FLAGS \
    && make install \
    && rm -rf $BUILD_DIR \
    && apt-get autoremove --purge -y $BUILD_PKGS \
    && rm -rf /var/lib/apt/lists/*

# Required for hindsight to source lua_sandbox libs.
#ENV LD_LIBRARY_PATH /usr/lib64

WORKDIR /hs

ENTRYPOINT ["/usr/bin/hindsight"]
