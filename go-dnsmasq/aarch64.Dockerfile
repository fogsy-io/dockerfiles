# Forked and modified from https://github.com/janeczku/go-dnsmasq

ARG BASE_IMG=arm64v8/alpine:3.9
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

ENV OS=linux \
    ARCH=arm

COPY qemu-aarch64-static /usr/bin

ADD go-dnsmasq_$OS-$ARCH /go-dnsmasq
RUN chmod +x /go-dnsmasq

ENV DNSMASQ_LISTEN=0.0.0.0
EXPOSE 53 53/udp
ENTRYPOINT ["/go-dnsmasq"]
