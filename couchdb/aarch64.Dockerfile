ARG BASE_IMG=arm64v8/debian:stretch-slim
FROM $BASE_IMG

ARG BUILD_DATE
ARG VCS_REF

LABEL io.fogsy.build-date=$BUILD_DATE \
      io.fogsy.license="Apache 2.0" \
      io.fogsy.organization="fogsy-io" \
      io.fogsy.url="https://fogsy.io/" \
      io.fogsy.vcs-ref=$VCS_REF \
      io.fogsy.vcs-type="Git" \
      io.fogsy.vcs-url="https://github.com/fogsy-io/dockerfiles"

COPY qemu-aarch64-static /usr/bin

ENV COUCHDB_VERSION=2.3.1 \
    TINI_VERSION=v0.18.0 \
    GOSU_VERSION=1.11

# Add CouchDB user account to make sure the IDs are assigned consistently
RUN groupadd -g 5984 -r couchdb && useradd -u 5984 -d /opt/couchdb -g couchdb couchdb

RUN set -ex; \
    \
    apt -y update; \
    apt -y --no-install-recommends install ca-certificates curl erlang-nox erlang-reltool libicu57 libmozjs185-1.0 openssl; \
    \
    DEPENDENCIES='python wget apt-transport-https gcc g++ erlang-dev libcurl4-openssl-dev libicu-dev libmozjs185-dev make'; \
    apt -y --no-install-recommends -y install ${DEPENDENCIES}; \
    mirror_url=$(wget -q -O - "http://www.apache.org/dyn/closer.cgi/?as_json=1" | python -c "import json,sys; print(json.loads(sys.stdin.read())['preferred'])"); \
    wget -q -O - ${mirror_url}/couchdb/source/${COUCHDB_VERSION}/apache-couchdb-${COUCHDB_VERSION}.tar.gz | tar -xzf - -C /tmp; \
    cd /tmp/apache-*; \
    ./configure --disable-docs; \
    make release; \
    cp -r rel/couchdb /opt/; \
    apt purge -y --auto-remove ${DEPENDENCIES}; \
    apt-get clean; \
    rm -rf /tmp/apache-* /var/lib/apt/lists/*

RUN set -ex; \
  	\
  	apt-get update; \
  	apt-get install -y --no-install-recommends wget; \
  	rm -rf /var/lib/apt/lists/*; \
  	\
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$dpkgArch"; \
    wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$dpkgArch"; \
    chmod +x /usr/local/bin/gosu; \
    chmod +x /usr/local/bin/tini;

COPY 10-docker-default.ini /opt/couchdb/etc/default.d/
COPY vm.args /opt/couchdb/etc/
COPY docker-entrypoint.sh /usr/local/bin/

RUN chown -R couchdb:couchdb /opt/couchdb
VOLUME ["/opt/couchdb/data"]
EXPOSE 5984 5986 4369 9100

ENTRYPOINT ["/usr/local/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["/opt/couchdb/bin/couchdb"]
