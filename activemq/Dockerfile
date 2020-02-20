ARG BASE_IMG=adoptopenjdk/openjdk8-openj9:alpine-slim
FROM $BASE_IMG

ENV ACTIVEMQ_VERSION=5.15.9

RUN set -x && \
    apk --update add --virtual build-dependencies curl && \
    curl -s https://archive.apache.org/dist/activemq/$ACTIVEMQ_VERSION/apache-activemq-$ACTIVEMQ_VERSION-bin.tar.gz | tar -xzf - -C /opt && \
    mv /opt/apache-activemq-$ACTIVEMQ_VERSION /opt/activemq && \
    apk del build-dependencies && \
    rm -rf /var/cache/apk/*

WORKDIR /opt/activemq

COPY activemq.xml /opt/activemq/conf

ENTRYPOINT ["/opt/activemq/bin/activemq",  "console"]
