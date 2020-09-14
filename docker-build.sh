#!/usr/bin/env bash

DOCKERHUB_REPO=$1

# base images
BASE_IMG_ALPINE_DEFAULT=alpine:3.9
BASE_IMG_ALPINE_ARM32V7=arm32v7/alpine:3.9
BASE_IMG_ALPINE_ARM64V8=arm64v8/alpine:3.9
BASE_IMG_JRE_DEFAULT=adoptopenjdk/openjdk8-openj9:alpine-slim
BASE_IMG_JRE_ARM32V7=arm32v7/openjdk:8-jre-alpine
BASE_IMG_JRE_ARM64V8=arm64v8/openjdk:8-jre-alpine
BASE_IMG_DEBIAN_DEFAULT=debian:stretch-slim
BASE_IMG_DEBIAN_ARM32V7=arm32v7/debian:stretch-slim
BASE_IMG_DEBIAN_ARM64V8=arm64v8/debian:stretch-slim

# image version tags
ACTIVEMQ_VERSION=5.15.9
CONSUL_VERSION=1.7.1
COUCHDB_VERSION=2.3.1
INFLUXDB_VERSION=1.7
KAFKA_VERSION=2.2.0
ZK_VERSION=3.4.13
DNSMASQ_VERSION=1.0.7
FLINK_VERSION=1.9.1-scala_2.11

docker_img_array=( activemq consul couchdb influxdb kafka zookeeper go-dnsmasq flink )

cp_qemu() {
	echo "======> Copy qemu static binaries: [ $1 ]"
	cp /usr/bin/{qemu-arm-static,qemu-aarch64-static} $1
}

build_go_binaries() {
	SERVICE=$1
	VERSION=$2

	echo "======> Building temporary go image [ $SERVICE:$VERSION ]"

	BUILD_IMAGE_NAME="go-dnsmasq-build"
	GOARCH=${GOARCH:-"amd64 arm arm64"}
	GOOS=${GOOS:-"linux"}

	docker build -t ${BUILD_IMAGE_NAME} -f- ./go-dnsmasq <<EOF
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
	    -v `pwd`/go-dnsmasq:/go/src/github.com/fogsyio/dockerfiles/go-dnsmasq \
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

}

docker_build_push() {
	TYPE=$1
	SERVICE=$2
	VERSION=$3
	IMG_NAME_DEFAULT=$DOCKERHUB_REPO/$SERVICE:$VERSION
	IMG_NAME_AMD64=$DOCKERHUB_REPO/$SERVICE:amd64-$VERSION
	IMG_NAME_ARM32V7=$DOCKERHUB_REPO/$SERVICE:arm32v7-$VERSION
	IMG_NAME_ARM64V8=$DOCKERHUB_REPO/$SERVICE:arm64v8-$VERSION

	if [ "$TYPE" == "jre" ]; then
			BASE_IMG_DEFAULT=$BASE_IMG_JRE_DEFAULT
			BASE_IMG_ARM32V7=$BASE_IMG_JRE_ARM32V7
			BASE_IMG_ARM64V8=$BASE_IMG_JRE_ARM64V8
	elif [ "$TYPE" == "debian" ]; then
			BASE_IMG_DEFAULT=$BASE_IMG_DEBIAN_DEFAULT
			BASE_IMG_ARM32V7=$BASE_IMG_DEBIAN_ARM32V7
			BASE_IMG_ARM64V8=$BASE_IMG_DEBIAN_ARM64V8
	elif [ "$TYPE" == "go" ]; then
			BASE_IMG_DEFAULT=$BASE_IMG_ALPINE_DEFAULT
			BASE_IMG_ARM32V7=$BASE_IMG_ALPINE_ARM32V7
			BASE_IMG_ARM64V8=$BASE_IMG_ALPINE_ARM64V8
	fi

	# build docker images
	echo "======> Building Docker Image: [ $IMG_NAME_DEFAULT, $IMG_NAME_AMD64 ]"
	docker build --pull \
	--build-arg BASE_IMG=$BASE_IMG_DEFAULT \
	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	-t $IMG_NAME_DEFAULT -t $IMG_NAME_AMD64 \
	-f $SERVICE/Dockerfile $SERVICE

	echo "======> Building Docker Image: [ $IMG_NAME_ARM32V7 ]"
	docker build --pull \
	--build-arg BASE_IMG=$BASE_IMG_ARM32V7 \
	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	-t $IMG_NAME_ARM32V7 \
	-f $SERVICE/arm.Dockerfile $SERVICE

	echo "======> Building Docker Image: [ $IMG_NAME_ARM64V8 ]"
	docker build --pull \
	--build-arg BASE_IMG=$BASE_IMG_ARM64V8 \
	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	-t $IMG_NAME_ARM64V8 \
	-f $SERVICE/aarch64.Dockerfile $SERVICE

	# push docker images
	docker push $IMG_NAME_DEFAULT
	docker push $IMG_NAME_AMD64
	docker push $IMG_NAME_ARM32V7
	docker push $IMG_NAME_ARM64V8

	# create manifest and push
	docker manifest create $IMG_NAME_DEFAULT $IMG_NAME_AMD64 $IMG_NAME_ARM32V7 $IMG_NAME_ARM64V8
	docker manifest annotate $IMG_NAME_DEFAULT $IMG_NAME_ARM32V7 --os linux --arch arm
	docker manifest annotate $IMG_NAME_DEFAULT $IMG_NAME_ARM64V8 --os linux --arch arm64
	docker manifest push $IMG_NAME_DEFAULT
}

docker_build_push_multiarch_existing() {
	SERVICE=$1
	VERSION=$2
	BASE_IMG=$SERVICE:$VERSION
	IMG_NAME_DEFAULT=$DOCKERHUB_REPO/$SERVICE:$VERSION
	IMG_NAME_AMD64=$DOCKERHUB_REPO/$SERVICE:amd64-$VERSION
	IMG_NAME_ARM32V7=$DOCKERHUB_REPO/$SERVICE:arm32v7-$VERSION
	IMG_NAME_ARM64V8=$DOCKERHUB_REPO/$SERVICE:arm64v8-$VERSION

	# build docker images
	echo "======> Building Docker Image: [ $IMG_NAME_DEFAULT, $IMG_NAME_AMD64 ]"
	docker build --pull \
	--build-arg BASE_IMG=$BASE_IMG \
	--build-arg ARCH=amd64 \
	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	-t $IMG_NAME_DEFAULT -t $IMG_NAME_AMD64 \
	-f $SERVICE/Dockerfile $SERVICE

	echo "======> Building Docker Image: [ $IMG_NAME_ARM32V7 ]"
	docker build --pull \
	--build-arg BASE_IMG=$BASE_IMG \
	--build-arg ARCH=arm \
	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	-t $IMG_NAME_ARM32V7 \
	-f $SERVICE/Dockerfile $SERVICE

	echo "======> Building Docker Image: [ $IMG_NAME_ARM64V8 ]"
	docker build --pull \
	--build-arg BASE_IMG=$BASE_IMG \
	--build-arg ARCH=arm64 \
	--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	--build-arg VCS_REF=`git rev-parse --short HEAD` \
	-t $IMG_NAME_ARM64V8 \
	-f $SERVICE/Dockerfile $SERVICE

	# push docker images
	docker push $IMG_NAME_DEFAULT
	docker push $IMG_NAME_AMD64
	docker push $IMG_NAME_ARM32V7
	docker push $IMG_NAME_ARM64V8

	# create manifest and push
	docker manifest create $IMG_NAME_DEFAULT $IMG_NAME_AMD64 $IMG_NAME_ARM32V7 $IMG_NAME_ARM64V8
	docker manifest annotate $IMG_NAME_DEFAULT $IMG_NAME_ARM32V7 --os linux --arch arm
	docker manifest annotate $IMG_NAME_DEFAULT $IMG_NAME_ARM64V8 --os linux --arch arm64
	docker manifest push $IMG_NAME_DEFAULT
}

for i in "${docker_img_array[@]}"
do
	echo "======> Building Docker Image: [ $i ]"

  if [ "$i" == "activemq" ]; then
		cp_qemu $i
		docker_build_push "jre" $i $ACTIVEMQ_VERSION

  elif [ "$i" == "consul" ]; then
		cp_qemu $i
		docker_build_push_multiarch_existing $i $CONSUL_VERSION

  elif [ "$i" == "couchdb" ]; then
		cp_qemu $i
		docker_build_push "debian" $i $COUCHDB_VERSION

  elif [ "$i" == "influxdb" ]; then
		cp_qemu $i
		docker_build_push_multiarch_existing $i $INFLUXDB_VERSION

  elif [ "$i" == "kafka" ]; then
		cp_qemu $i
		docker_build_push "jre" $i $KAFKA_VERSION

  elif [ "$i" == "zookeeper" ]; then
		cp_qemu $i
		docker_build_push "jre" $i $ZK_VERSION

  elif [ "$i" == "go-dnsmasq" ]; then
		cp_qemu $i
		build_go_binaries $DNSMASQ_VERSION
		docker_build_push "go" $i $DNSMASQ_VERSION

  elif [ "$i" == "flink" ]; then
		cp_qemu $i
		docker_build_push "jre" $i $FLINK_VERSION
  fi

done
