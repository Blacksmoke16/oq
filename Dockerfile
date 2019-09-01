FROM alpine:latest

RUN echo '@edge http://dl-cdn.alpinelinux.org/alpine/edge/main' >>/etc/apk/repositories \
    && echo '@edge http://dl-cdn.alpinelinux.org/alpine/edge/community' >>/etc/apk/repositories \
    && apk add --update --no-cache --force-overwrite \
        crystal@edge \
        gc-dev \
        libevent-dev \
        libevent-static \
        libunwind-dev \
        libxml2-dev \
        g++ \
        llvm \
        llvm-dev \
        llvm-static \
        make \
        musl-dev \
        openssl-dev \
        pcre-dev \
        readline-dev \
        shards \
        yaml-dev \
        zlib-dev


docker run --rm -it -v $PWD:/app -w /app alpine crystal build --static --release src/oq_cli.cr

