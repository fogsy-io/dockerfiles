#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "The version number must be passed to this script"
    exit 1
fi
VERSION=$1

echo "======> Building binary $VERSION"

BUILD_IMAGE_NAME="go-dnsmasq-build"
GOARCH=${GOARCH:-"amd64 arm arm64"}
GOOS=${GOOS:-"linux"}

docker build -t ${BUILD_IMAGE_NAME} -f- . <<EOF
FROM golang:1.13

# TODO: Vendor these `go get` commands using Godep.
RUN \
  go get github.com/mitchellh/gox; \
  go get github.com/aktau/github-release; \
  go get github.com/pwaller/goupx; \
  go get github.com/urfave/cli; \
  go get github.com/coreos/go-systemd/activation; \
  go get github.com/miekg/dns; \
  go get github.com/rcrowley/go-metrics; \
  go get github.com/rcrowley/go-metrics/stathat; \
  go get github.com/sirupsen/logrus; \
  go get github.com/stathat/go

RUN \
  apt update; \
  apt install -y xz-utils; \
  wget -P /tmp https://github.com/upx/upx/releases/download/v3.96/upx-3.96-amd64_linux.tar.xz; \
  tar -xf /tmp/upx-3.96-amd64_linux.tar.xz -C /tmp; \
  mv /tmp/upx-3.96-amd64_linux/upx /usr/local/bin;

ENV USER root

ADD . /go/src/github.com/fogsyio/dockerfiles/go-dnsmasq

WORKDIR /go/src/github.com/fogsyio/dockerfiles/go-dnsmasq
EOF

echo "======> Building go-binaries for [ $GOARCH ]"

sleep 2

docker run --rm \
    -v `pwd`:/go/src/github.com/fogsyio/dockerfiles/go-dnsmasq \
    ${BUILD_IMAGE_NAME} \
    gox \
    -os "$GOOS" \
    -arch "$GOARCH" \
    -output="go-dnsmasq_{{.OS}}-{{.Arch}}" \
    -ldflags "-w -s -X main.Version=$VERSION" \
    -tags="netgo" \
    -rebuild

echo "======> Remove temporary image [ $BUILD_IMAGE_NAME ]"
docker rmi ${BUILD_IMAGE_NAME} 2> /dev/null
