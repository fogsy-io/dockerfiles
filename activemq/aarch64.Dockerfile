ARG BASE_IMG=arm64v8/openjdk:8-jre-alpine
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

ENV ACTIVEMQ_VERSION=5.15.9

COPY qemu-aarch64-static /usr/bin

RUN set -x && \
    apk --update add --virtual build-dependencies curl && \
    curl -s https://archive.apache.org/dist/activemq/$ACTIVEMQ_VERSION/apache-activemq-$ACTIVEMQ_VERSION-bin.tar.gz | tar -xzf - -C /opt && \
    mv /opt/apache-activemq-$ACTIVEMQ_VERSION /opt/activemq && \
    apk del build-dependencies && \
    rm -rf /var/cache/apk/*

WORKDIR /opt/activemq

COPY activemq.xml /opt/activemq/conf

ENTRYPOINT ["/opt/activemq/bin/activemq",  "console"]
