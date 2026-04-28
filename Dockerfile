FROM crystallang/crystal:1.20.0

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libssh2-1-dev libssl-dev libgmp-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . /workspace
