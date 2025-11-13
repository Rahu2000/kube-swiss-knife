#!/bin/bash

REPO_IMAGE=$1
TAG=$2
NAMESPACE=""
REGISTRY=""

# 필수 입력 확인
if [ -z "$REPO_IMAGE" ] || [ -z "$TAG" ]; then
  echo "Usage: $0 <REPO_IMAGE> <TAG> [--namespace|-n <NAMESPACE>] [--registry|-r <REGISTRY>]"
  exit 1
fi

# NAMESPACE 및 REGISTRY 처리
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace|-n)
      NAMESPACE=$2
      shift 2
      ;;
    --registry|-r)
      REGISTRY=$2
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$NAMESPACE" ]; then
  NAMESPACE="k8s.io"
fi

if [ -z "$REGISTRY" ]; then
  REGISTRY="registry.k8s.io"
fi

echo "Using repository image: $REPO_IMAGE"
echo "Using tag: $TAG"
echo "Using namespace: $NAMESPACE"
echo "Using registry: $REGISTRY"

# QEMU 에뮬레이터 설정
docker run --privileged --rm tonistiigi/binfmt --install all

# 빌더 생성 및 설정
docker buildx create --name multiarch-builder --driver docker-container --use
docker buildx inspect --bootstrap

# 멀티 아키텍처 빌드 및 푸시
docker buildx build --platform linux/amd64,linux/arm64 -t $REPO_IMAGE:$TAG --build-arg NAMESPACE="$NAMESPACE" --build-arg REGISTRY="$REGISTRY" --push .

docker buildx rm multiarch-builder
