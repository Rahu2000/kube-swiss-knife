#!/bin/bash

REPO_IMAGE=$1
TAG=$2
NAMESPACE=${3:-k8s.io}

echo $NAMESPACE
# QEMU 에뮬레이터 설정
docker run --privileged --rm tonistiigi/binfmt --install all

# 빌더 생성 및 설정
docker buildx create --name multiarch-builder --driver docker-container --use
docker buildx inspect --bootstrap

# 멀티 아키텍처 빌드 및 푸시
docker buildx build --platform linux/amd64,linux/arm64 -t $REPO_IMAGE:$TAG --build-arg NAMESPACE=$NAMESPACE --push .

docker buildx rm multiarch-builder
