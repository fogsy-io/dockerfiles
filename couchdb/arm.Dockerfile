ARG BASE_IMAGE=arm32v7/debian:stretch-slim
FROM $BASE_IMAGE

ARG BUILD_DATE
ARG VCS_REF

LABEL io.fogsy.build-date=$BUILD_DATE \
      io.fogsy.license="Apache 2.0" \
      io.fogsy.organization="fogsy-io" \
      io.fogsy.url="https://fogsy.io/" \
      io.fogsy.vcs-ref=$VCS_REF \
      io.fogsy.vcs-type="Git" \
      io.fogsy.vcs-url="https://github.com/fogsy-io/dockerfiles"

COPY qemu-arm-static /usr/bin

ENV COUCHDB_VERSION=2.3.1 \
    TINI_ARCH=static-armhf \
    TINI_VERSION=v0.18.0

RUN set -x \
    && echo "install runtime dependencies" \
    && apt -y update \
    && apt -y --no-install-recommends install ca-certificates curl erlang-nox erlang-reltool libicu57 libmozjs185-1.0 openssl

RUN set -x \
    && DEPENDENCIES='python wget apt-transport-https gcc g++ erlang-dev libcurl4-openssl-dev libicu-dev libmozjs185-dev make' \
    && echo "install build dependencies" \
    && apt -y --no-install-recommends -y install ${DEPENDENCIES} \
    && echo "download couchdb source code" \
    && mirror_url=$(wget -q -O - "http://www.apache.org/dyn/closer.cgi/?as_json=1" | python -c "import json,sys; print(json.loads(sys.stdin.read())['preferred'])") \
    && wget -q -O - ${mirror_url}/couchdb/source/${COUCHDB_VERSION}/apache-couchdb-${COUCHDB_VERSION}.tar.gz | tar -xzf - -C /tmp \
    && echo "build couchdb" \
    && cd /tmp/apache-* \
    && ./configure --disable-docs \
    && make release \
    && cp -r rel/couchdb /opt/ \
    && echo "remove build dependencies" \
    && apt purge -y --auto-remove ${DEPENDENCIES} \
    && apt-get clean \
    && rm -rf /tmp/apache-* /var/lib/apt/lists/*

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TINI_ARCH} /usr/local/bin/tini
RUN chmod +x /usr/local/bin/tini

COPY 10-docker-default.ini /opt/couchdb/etc/default.d/
COPY vm.args /opt/couchdb/etc/
COPY docker-entrypoint.sh /usr/local/bin/

VOLUME ["/opt/couchdb/data"]
EXPOSE 5984 5986 4369 9100

ENTRYPOINT ["/usr/local/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["/opt/couchdb/bin/couchdb"]
