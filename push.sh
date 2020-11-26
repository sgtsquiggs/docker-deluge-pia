#!/usr/bin/env sh
set -e

IMAGE=$1
BUILDER=$2

docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx use "${BUILDER}"
docker buildx build --push --platform linux/amd64,linux/arm,linux/arm64 -t "${IMAGE}:latest" .
docker pushrm "${IMAGE}"
