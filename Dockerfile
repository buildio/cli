FROM crystallang/crystal:latest-alpine

WORKDIR /workspace

RUN apk upgrade \
    && apk add --update --no-cache ca-certificates libssh2-static lz4-dev lz4-static yaml-static gmp-dev gmp-static \
       perl make linux-headers \
    && wget https://github.com/openssl/openssl/releases/download/openssl-3.6.2/openssl-3.6.2.tar.gz \
    && tar xzf openssl-3.6.2.tar.gz \
    && cd openssl-3.6.2 \
    && ./Configure linux-x86_64 no-shared --prefix=/usr --openssldir=/etc/ssl \
    && make -j$(nproc) \
    && make install_sw \
    && cd .. && rm -rf openssl-3.6.2 openssl-3.6.2.tar.gz

COPY . /workspace
