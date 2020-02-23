[![Github Actions](https://img.shields.io/github/workflow/status/fogsy-io/dockerfiles/CI)](https://github.com/fogsy-io/dockerfiles/actions/)
## dockerfiles
This repository contains a collection of Dockerfiles for multi-arch builds. Some images such as **consul** and **influxdb** already provide multi-arch support such that we only edited the Docker image tags.

### Supported architectures
Currently, the resulting Docker images support the following CPU architectures:

* `amd64`
* `arm32v7`
* `arm64v8`

### Credits
* Thanks to [wurstmeister](https://github.com/wurstmeister) for his great work on Kafka and Zookeeper Docker images
* Thanks to [consul](https://github.com/hashicorp/docker-consul) and [influxdb](https://github.com/influxdata/influxdata-docker) community for already providing multi-arch images.
