FROM crystallang/crystal:latest-alpine

WORKDIR /workspace

RUN apk upgrade \
    && apk add --update --no-cache ca-certificates libssh2-static lz4-dev lz4-static yaml-static gmp-dev gmp-static \
       perl make linux-headers \
    && apk del openssl-dev openssl-libs-static 2>/dev/null; true \
    && rm -f /usr/lib/libssl.a /usr/lib/libcrypto.a \
    && wget https://github.com/openssl/openssl/releases/download/openssl-3.6.2/openssl-3.6.2.tar.gz \
    && tar xzf openssl-3.6.2.tar.gz \
    && cd openssl-3.6.2 \
    && ./Configure linux-x86_64 no-shared enable-deprecated --prefix=/usr --openssldir=/etc/ssl \
    && make -j$(nproc) \
    && make install_sw \
    && cd .. && rm -rf openssl-3.6.2 openssl-3.6.2.tar.gz \
    && printf 'int EVP_MD_get_size(const void*);\nint EVP_MD_size(const void *md){return EVP_MD_get_size(md);}\n' \
       | gcc -xc -c -o /tmp/compat.o - \
    && ar r /usr/lib/libcrypto.a /tmp/compat.o && rm /tmp/compat.o \
    && /usr/bin/openssl version

COPY . /workspace
