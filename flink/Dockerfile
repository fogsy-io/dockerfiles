ARG BASE_IMG=adoptopenjdk/openjdk8-openj9:alpine-slim
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

# Install Flink
ENV FLINK_VERSION=1.13.2 \
    SCALA_VERSION=2.11 \
    GOSU_VERSION=1.11

# Install dependencies
RUN set -ex; \
  apk --update --no-cache \
  add snappy-dev snappy gettext wget gnupg dpkg bash; \
  rm -rf /var/lib/apt/lists/*

# Grab gosu for easy step-down from root
RUN set -ex; \
  wget -nv -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
  wget -nv -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }').asc"; \
  export GNUPGHOME="$(mktemp -d)"; \
  for server in ha.pool.sks-keyservers.net $(shuf -e \
                          hkp://p80.pool.sks-keyservers.net:80 \
                          keyserver.ubuntu.com \
                          hkp://keyserver.ubuntu.com:80 \
                          pgp.mit.edu) ; do \
      gpg --batch --keyserver "$server" --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && break || : ; \
  done && \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
  gpgconf --kill all; \
  rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
  chmod +x /usr/local/bin/gosu; \
  gosu nobody true

# Configure Flink version
ENV FLINK_TGZ_URL=https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz \
    FLINK_ASC_URL=https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz.asc

# Prepare environment
ENV FLINK_HOME=/opt/flink
ENV PATH=$FLINK_HOME/bin:$PATH
RUN addgroup --system --gid 9999 flink && \
    adduser -S -h $FLINK_HOME -u 9999 -G flink flink
WORKDIR $FLINK_HOME

# Install Flink
RUN set -ex; \
  wget -nv -O flink.tgz "$FLINK_TGZ_URL"; \
  \
  tar -xf flink.tgz --strip-components=1; \
  rm flink.tgz; \
  \
  chown -R flink:flink .;

# Configure container
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 6123 8081
CMD ["help"]
