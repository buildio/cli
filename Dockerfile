FROM crystallang/crystal:latest-alpine

WORKDIR /workspace

RUN apk upgrade \
    && apk add --update --no-cache ca-certificates libssh2-static lz4-dev lz4-static yaml-static gmp-dev gmp-static

COPY . /workspace
