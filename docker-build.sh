#!/usr/bin/env bash

DOCKERHUB_REPO=$1
# MVN_VERSION=$2
BASE_IMG_JRE_DEFAULT=$2
BASE_IMG_JRE_ARM32V7=$3
BASE_IMG_JRE_ARM64V8=$4

ACTIVEMQ_VERSION=5.15.9
CONSUL_VERSION=1.7.0
COUCHDB_VERSION=2.3.1
INFLUXDB_VERSION=1.7
KAFKA_VERSION=2.2.0
ZK_VERSION=3.4.13

array=( activemq consul couchdb influxdb kafka zookeeper )
for i in "${array[@]}"
do
	echo "======> Building Docker Image: [ $i ]"

  # set env vars
  # IMG_NAME_DEFAULT=$DOCKERHUB_REPO/$i:$MVN_VERSION
  # IMG_NAME_AMD64=$DOCKERHUB_REPO/$i:amd64-$MVN_VERSION
  # IMG_NAME_ARM32V7=$DOCKERHUB_REPO/$i:arm32v7-$MVN_VERSION
  # IMG_NAME_ARM64V8=$DOCKERHUB_REPO/$i:arm64v8-$MVN_VERSION
  if [ "$i" == "activemq" ]; then
    VERSION=$ACTIVEMQ_VERSION
  elif [ "$i" == "consul" ]; then
    VERSION=$CONSUL_VERSION
  elif [ "$i" == "couchdb" ]; then
    VERSION=$COUCHDB_VERSION
  elif [ "$i" == "influxdb" ]; then
    VERSION=$INFLUXDB_VERSION
  elif [ "$i" == "kafka" ]; then
    VERSION=$KAFKA_VERSION
  elif [ "$i" == "zookeeper" ]; then
    VERSION=$ZK_VERSION
  fi

  IMG_NAME_DEFAULT=$DOCKERHUB_REPO/$i:$VERSION
  IMG_NAME_AMD64=$DOCKERHUB_REPO/$i:amd64-$VERSION
  IMG_NAME_ARM32V7=$DOCKERHUB_REPO/$i:arm32v7-$VERSION
  IMG_NAME_ARM64V8=$DOCKERHUB_REPO/$i:arm64v8-$VERSION

  # copy qemu to service dir
  cp /usr/bin/{qemu-arm-static,qemu-aarch64-static} $i

  # build docker images
  docker build --pull --build-arg BASE_IMG=$BASE_IMG_JRE_DEFAULT -t $IMG_NAME_DEFAULT -t $IMG_NAME_AMD64 -f Dockerfile $i
  docker build --pull --build-arg BASE_IMG=$BASE_IMG_JRE_ARM32V7 -t $IMG_NAME_ARM32V7 -f arm.Dockerfile $i
  docker build --pull --build-arg BASE_IMG=$BASE_IMG_JRE_ARM64V8 -t $IMG_NAME_ARM64V8 -f aarch64.Dockerfile $i

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
done
