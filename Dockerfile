# Musl build must implement pthread_timedjoin_np.
# For this we can use alpine:edge and upgrade to at least v1.1.15.
FROM alpine:edge

ENV LUA_SANDBOX_REF            master
ENV LUA_SANDBOX_EXTENSIONS_REF master
ENV HINDSIGHT_REF              master

ENV BUILD_DIR /build
ARG MAKE_FLAGS="-j4"

ENV LUA_SANDBOX_REQUIRED_BUILD_PKGS gcc g++ make cmake git ca-certificates lua5.1-dev
ENV LUA_SANDBOX_OPTIONAL_BUILD_PKGS openssl-dev zlib-dev geoip-dev

RUN apk upgrade --update-cache --available \
    # Build dependencies
    && apk add --virtual .build-deps \
        $LUA_SANDBOX_REQUIRED_BUILD_PKGS \
        $LUA_SANDBOX_OPTIONAL_BUILD_PKGS \
    && mkdir $BUILD_DIR \
    && cd $BUILD_DIR \
    # Clone repos
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
        # Disable some extensions for now that require external libs.
        # TODO: add libs for these
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
    && cmake -DCMAKE_BUILD_TYPE=release -DCMAKE_INSTALL_PREFIX:PATH=/usr .. \
    && make $MAKE_FLAGS \
    && make install \
    && rm -rf $BUILD_DIR \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

# Required for hindsight to source lua_sandbox libs
ENV LD_LIBRARY_PATH /usr/lib64

WORKDIR /hs

ENTRYPOINT ["/usr/bin/hindsight"]
