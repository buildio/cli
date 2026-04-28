FROM crystallang/crystal:latest-alpine

WORKDIR /workspace

RUN apk upgrade \
    && apk add --update --no-cache ca-certificates libssh2-static lz4-dev lz4-static yaml-static gmp-dev gmp-static \
    && apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main \
       openssl-dev openssl-libs-static

COPY . /workspace
