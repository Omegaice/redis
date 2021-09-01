FROM alpine:3.9 as BUILDER
RUN apk add --no-cache \
        build-base \
        musl-dev \
        automake \
        make \
        cmake \
        autoconf \
        libtool \
        wget \
        g++ \
        m4 \
        libgomp \
        python \
        py-setuptools \
        py-pip \
        git \
        ;\
    pip install rmtest;\
    pip install redisgraph;

# Install PEG manually (because there is no Alpine package for it).
RUN wget https://www.piumarta.com/software/peg/peg-0.1.18.tar.gz;\
    tar xzf peg-0.1.18.tar.gz;\
    cd peg-0.1.18;\
    make; make install

RUN git clone --recurse-submodules -j8 https://github.com/RedisGraph/RedisGraph.git /opt/RedisGraph
WORKDIR /opt/RedisGraph
RUN make

FROM alpine:3.9

MAINTAINER Opstree Solutions

LABEL VERSION=1.0 \
      ARCH=AMD64 \
      DESCRIPTION="A production grade performance tuned redis docker image created by Opstree Solutions"

ARG REDIS_DOWNLOAD_URL="http://download.redis.io/"

ARG REDIS_VERSION="stable"

RUN addgroup -S -g 1001 redis && adduser -S -G redis -u 1001 redis && \
    apk add --no-cache su-exec tzdata make curl build-base linux-headers bash libgomp
    
COPY --from=BUILDER /opt/RedisGraph/src/redisgraph.so /usr/lib/redis/modules/

RUN curl -fL -Lo /tmp/redis-${REDIS_VERSION}.tar.gz ${REDIS_DOWNLOAD_URL}/redis-${REDIS_VERSION}.tar.gz && \
    cd /tmp && \
    tar xvzf redis-${REDIS_VERSION}.tar.gz && \
    cd redis-${REDIS_VERSION} && \
    make && \
    make install && \
    mkdir -p /etc/redis && \
    cp -f *.conf /etc/redis && \
    rm -rf /tmp/redis-${REDIS_VERSION}* && \
    apk del curl make

COPY redis.conf /etc/redis/redis.conf

COPY entrypoint.sh /usr/bin/entrypoint.sh

COPY setupMasterSlave.sh /usr/bin/setupMasterSlave.sh

COPY healthcheck.sh /usr/bin/healthcheck.sh

RUN mkdir -p /opt/redis/ && \
    chmod -R g+rwX /etc/redis /opt/redis

VOLUME ["/data"]

WORKDIR /data

EXPOSE 6379

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
