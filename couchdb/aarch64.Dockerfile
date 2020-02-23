ARG BASE_IMAGE=arm64v8/debian:stretch-slim
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

COPY qemu-aarch64-static /usr/bin

# Add CouchDB user account to make sure the IDs are assigned consistently
RUN groupadd -g 5984 -r couchdb && useradd -u 5984 -d /opt/couchdb -g couchdb couchdb

# be sure GPG and apt-transport-https are available and functional
RUN set -ex; \
        apt-get update; \
        apt-get install -y --no-install-recommends \
                apt-transport-https \
                ca-certificates \
                dirmngr \
                gnupg \
        ; \
        rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root and tini for signal handling and zombie reaping
# see https://github.com/apache/couchdb-docker/pull/28#discussion_r141112407
ENV GOSU_VERSION 1.11
ENV TINI_VERSION 0.18.0
RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends wget; \
	rm -rf /var/lib/apt/lists/*; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	\
# install gosu
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
        echo "disable-ipv6" >> ${GNUPGHOME}/dirmngr.conf; \
        for server in $(shuf -e pgpkeys.mit.edu \
            ha.pool.sks-keyservers.net \
            hkp://p80.pool.sks-keyservers.net:80 \
            pgp.mit.edu) ; do \
        gpg --batch --keyserver $server --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && break || : ; \
        done; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	chmod +x /usr/local/bin/gosu; \
	gosu nobody true; \
    \
# install tini
	wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-$dpkgArch"; \
	wget -O /usr/local/bin/tini.asc "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
        echo "disable-ipv6" >> ${GNUPGHOME}/dirmngr.conf; \
        for server in $(shuf -e pgpkeys.mit.edu \
            ha.pool.sks-keyservers.net \
            hkp://p80.pool.sks-keyservers.net:80 \
            pgp.mit.edu) ; do \
        gpg --batch --keyserver $server --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 && break || : ; \
        done; \
	gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini; \
	rm -rf "$GNUPGHOME" /usr/local/bin/tini.asc; \
	chmod +x /usr/local/bin/tini; \
        apt-get purge -y --auto-remove wget; \
	tini --version

# http://docs.couchdb.org/en/latest/install/unix.html#installing-the-apache-couchdb-packages
ENV GPG_COUCH_KEY \
# gpg: key D401AB61: public key "Bintray (by JFrog) <bintray@bintray.com> imported
       8756C4F765C9AC3CB6B85D62379CE192D401AB61
RUN set -xe; \
        export GNUPGHOME="$(mktemp -d)"; \
        echo "disable-ipv6" >> ${GNUPGHOME}/dirmngr.conf; \
        for server in $(shuf -e pgpkeys.mit.edu \
            ha.pool.sks-keyservers.net \
            hkp://p80.pool.sks-keyservers.net:80 \
            pgp.mit.edu) ; do \
                gpg --batch --keyserver $server --recv-keys $GPG_COUCH_KEY && break || : ; \
        done; \
        gpg --batch --export $GPG_COUCH_KEY > /etc/apt/trusted.gpg.d/couchdb.gpg; \
        command -v gpgconf && gpgconf --kill all || :; \
        rm -rf "$GNUPGHOME"; \
        apt-key list

ENV COUCHDB_VERSION 2.3.1

RUN echo "deb https://apache.bintray.com/couchdb-deb stretch main" > /etc/apt/sources.list.d/couchdb.list

# https://github.com/apache/couchdb-pkg/blob/master/debian/README.Debian
RUN set -xe; \
        apt-get update; \
        \
        echo "couchdb couchdb/mode select none" | debconf-set-selections; \
# we DO want recommends this time
        DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
                couchdb="$COUCHDB_VERSION"~stretch \
        ; \
# Undo symlinks to /var/log and /var/lib
        rmdir /var/lib/couchdb /var/log/couchdb; \
        rm /opt/couchdb/data /opt/couchdb/var/log; \
        mkdir -p /opt/couchdb/data /opt/couchdb/var/log; \
        chown couchdb:couchdb /opt/couchdb/data /opt/couchdb/var/log; \
        chmod 777 /opt/couchdb/data /opt/couchdb/var/log; \
# Remove file that sets logging to a file
        rm /opt/couchdb/etc/default.d/10-filelog.ini; \
        rm -rf /var/lib/apt/lists/*

# Add configuration
COPY 10-docker-default.ini /opt/couchdb/etc/default.d/
COPY vm.args /opt/couchdb/etc/
COPY docker-entrypoint.sh /usr/local/bin
RUN ln -s usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh # backwards compat
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

# Setup directories and permissions
RUN chown -R couchdb:couchdb /opt/couchdb/etc/default.d/ /opt/couchdb/etc/vm.args
VOLUME /opt/couchdb/data

# 5984: Main CouchDB endpoint
# 4369: Erlang portmap daemon (epmd)
# 9100: CouchDB cluster communication port
EXPOSE 5984 4369 9100
CMD ["/opt/couchdb/bin/couchdb"]

# ARG BASE_IMAGE=arm64v8/debian:stretch-slim
# FROM $BASE_IMAGE
#
# COPY qemu-aarch64-static /usr/bin
#
# # Add CouchDB user account
# RUN groupadd -r couchdb && useradd -d /opt/couchdb -g couchdb couchdb
#
# RUN apt-get update -y && apt-get install -y --allow-unauthenticated --no-install-recommends \
#     ca-certificates \
#     curl \
#     erlang-nox \
#     erlang-reltool \
#     haproxy \
#     libicu57 \
#     libmozjs185-1.0 \
#     openssl \
#     gnupg \
#     dirmngr \
#   && rm -rf /var/lib/apt/lists/*
#
# # grab gosu for easy step-down from root and tini for signal handling
# # see https://github.com/apache/couchdb-docker/pull/28#discussion_r141112407
# # Update GOSU to 1.11 and Tini to 0.18.0
# ENV GOSU_VERSION 1.11
# ENV TINI_VERSION 0.18.0
# RUN set -ex; \
# 	\
# 	apt-get update; \
# 	apt-get install -y --allow-unauthenticated --no-install-recommends wget; \
# 	rm -rf /var/lib/apt/lists/*; \
# 	\
# 	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
# 	\
# # install gosu
# 	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$dpkgArch"; \
# 	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
# 	export GNUPGHOME="$(mktemp -d)"; \
# 	gpg --no-tty --keyserver ipv4.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
# 	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
# 	rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc; \
# 	chmod +x /usr/local/bin/gosu; \
# 	\
# # check if tini exists
#         if ! type "tini" > /dev/null; then \
#         \
# # if not then install tini
# 	wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-$dpkgArch"; \
# 	wget -O /usr/local/bin/tini.asc "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-$dpkgArch.asc"; \
# 	export GNUPGHOME="$(mktemp -d)"; \
# 	gpg --no-tty --keyserver ipv4.pool.sks-keyservers.net --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7; \
# 	gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini; \
# 	rm -r "$GNUPGHOME" /usr/local/bin/tini.asc; \
# 	chmod +x /usr/local/bin/tini; \
# 	tini --version; \
# 	\
# 	fi; \
# 	apt-get purge -y --auto-remove wget
#
# # https://www.apache.org/dist/couchdb/KEYS
# # The key part?
# ENV GPG_KEYS \
#   15DD4F3B8AACA54740EB78C7B7B7C53943ECCEE1 \
#   1CFBFA43C19B6DF4A0CA3934669C02FFDF3CEBA3 \
#   25BBBAC113C1BFD5AA594A4C9F96B92930380381 \
#   4BFCA2B99BADC6F9F105BEC9C5E32E2D6B065BFB \
#   5D680346FAA3E51B29DBCB681015F68F9DA248BC \
#   7BCCEB868313DDA925DF1805ECA5BCB7BB9656B0 \
#   C3F4DFAEAD621E1C94523AEEC376457E61D50B88 \
#   D2B17F9DA23C0A10991AF2E3D9EE01E47852AEE4 \
#   E0AF0A194D55C84E4A19A801CDB0C0F904F4EE9B \
#   29E4F38113DF707D722A6EF91FE9AF73118F1A7C \
#   2EC788AE3F239FA13E82D215CDE711289384AE37
# RUN set -xe \
#   && for key in $GPG_KEYS; do \
#     gpg --no-tty --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$key"; \
#   done
#
# ENV COUCHDB_VERSION 2.3.1
#
# # Download dev dependencies
# RUN buildDeps=' \
#     apt-transport-https \
#     gcc \
#     g++ \
#     erlang-dev \
#     libcurl4-openssl-dev \
#     libicu-dev \
#     libmozjs185-dev \
#     make \
#   ' \
#  && apt-get update -y -qq && apt-get install -y --allow-unauthenticated --no-install-recommends $buildDeps \
#  # Acquire CouchDB source code
#  && cd /usr/src && mkdir couchdb \
#  && c_rehash \
#  && curl -fSL https://dist.apache.org/repos/dist/release/couchdb/source/$COUCHDB_VERSION/apache-couchdb-$COUCHDB_VERSION.tar.gz -o couchdb.tar.gz \
#  && curl -fSL https://dist.apache.org/repos/dist/release/couchdb/source/$COUCHDB_VERSION/apache-couchdb-$COUCHDB_VERSION.tar.gz.asc -o couchdb.tar.gz.asc \
#  && gpg --batch --verify couchdb.tar.gz.asc couchdb.tar.gz \
#  && tar -xzf couchdb.tar.gz -C couchdb --strip-components=1 \
#  && cd couchdb \
#  # Build the release and install into /opt
#  && ./configure --disable-docs \
#  && make release \
#  && mv /usr/src/couchdb/rel/couchdb /opt/ \
#  # Cleanup build detritus
#  && apt-get purge -y --auto-remove $buildDeps \
#  && rm -rf /var/lib/apt/lists/* /usr/src/couchdb* \
#  && mkdir /opt/couchdb/data \
#  && chown -R couchdb:couchdb /opt/couchdb
#
# # Add configuration
# COPY local.ini /opt/couchdb/etc/default.d/
# COPY vm.args /opt/couchdb/etc/
#
# COPY ./docker-entrypoint.sh /
#
# # Setup directories and permissions
# RUN chown -R couchdb:couchdb /opt/couchdb/etc/default.d/ /opt/couchdb/etc/vm.args
#
# WORKDIR /opt/couchdb
# EXPOSE 5984 4369 9100
# VOLUME ["/opt/couchdb/data"]
#
# ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
# CMD ["/opt/couchdb/bin/couchdb"]
