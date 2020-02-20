ARG BASE_IMG=arm64v8/openjdk:8-jre-alpine
FROM $BASE_IMG

ARG ZK_VERSION=3.4.13

COPY qemu-aarch64-static /usr/bin

ENV ZK_HOME /opt/zookeeper-$ZK_VERSION

RUN set -x && \
    apk --update add bash && \
    apk --update add --virtual build-dependencies curl && \
    curl -s https://archive.apache.org/dist/zookeeper/zookeeper-$ZK_VERSION/zookeeper-$ZK_VERSION.tar.gz | tar -xzvf - -C /opt && \
    mv $ZK_HOME/conf/zoo_sample.cfg $ZK_HOME/conf/zoo.cfg && \
    sed  -i "s|/tmp/zookeeper|$ZK_HOME/data|g" $ZK_HOME/conf/zoo.cfg && \
    mkdir -p $ZK_HOME/data && \
    apk del build-dependencies && \
    rm -rf /var/cache/apk/*

WORKDIR /opt/zookeeper-$ZK_VERSION

EXPOSE 2181 2888 3888

CMD ["bin/zkServer.sh", "start-foreground"]
