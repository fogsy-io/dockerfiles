ARG BASE_IMG=consul:1.7.1
ARG ARCH
FROM --platform=$ARCH $BASE_IMG

ARG BUILD_DATE
ARG VCS_REF

LABEL io.fogsy.build-date=$BUILD_DATE \
      io.fogsy.license="Apache 2.0" \
      io.fogsy.organization="fogsy-io" \
      io.fogsy.url="https://fogsy.io/" \
      io.fogsy.vcs-ref=$VCS_REF \
      io.fogsy.vcs-type="Git" \
      io.fogsy.vcs-url="https://github.com/fogsy-io/dockerfiles"

CMD [ "/bin/sh", "-c", \
      "consul agent", \
      "-server", \
      "-bootstrap-expect=1", \
      "-data-dir=/consul/data", \
      "-node=consul-one", \
      "-bind='{{ GetInterfaceIP "eth0" }}'", \
      "-client=0.0.0.0", \
      "-enable-script-checks=true", \
      "-ui" ]
