#!/bin/bash
tag=python3-kubernetes:12.0
docker build -t "$tag" -f Dockerfile.api-v12 .
docker tag "$tag" harbor.mellanox.com/swx-storage/x86_64/$tag
docker push harbor.mellanox.com/swx-storage/x86_64/$tag
