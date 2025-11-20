#!/bin/sh

set -ex

echo "Starting disk cleanup script..."

NERDCTL_PATH=$(command -v nerdctl 2>/dev/null)
CTR_PATH=$(command -v ctr 2>/dev/null)
NAMESPACE=${NAMESPACE:-k8s.io}
REGISTRY=${REGISTRY:-registry.k8s.io}

# Kubelet 프로세스에서 실제 pause 이미지 경로를 동적으로 확인
KUBELET_PAUSE_IMAGE=$(ps aux | grep kubelet | grep -o -E 'pod-infra-container-image=[^ ]+' | cut -d '=' -f 2)

# 동적으로 확인하지 못했을 경우를 대비한 기본값
if [ -z "$KUBELET_PAUSE_IMAGE" ]; then
  echo "Warning: Could not dynamically determine pause image from kubelet process. Falling back to default." >&2
  KUBELET_PAUSE_IMAGE="localhost/kubernetes/pause:latest" # 또는 다른 안전한 기본값
fi

echo "Target pause image to preserve: $KUBELET_PAUSE_IMAGE"

# 정리 후 pause 이미지가 없을 경우 복구하는 함수
ensure_pause_image() {
  TOOL=$1
  echo "Kubelet's pause image ($KUBELET_PAUSE_IMAGE) not found after cleanup. Attempting to restore..."
  if [ "$TOOL" = "nerdctl" ] && nerdctl --namespace "$NAMESPACE" pull "$REGISTRY/pause:latest"; then
    nerdctl --namespace "$NAMESPACE" tag "$REGISTRY/pause:latest" "$KUBELET_PAUSE_IMAGE"
    echo "Successfully restored pause image."
  elif [ "$TOOL" = "ctr" ] && ctr --namespace "$NAMESPACE" images pull "$REGISTRY/pause:latest"; then
    ctr --namespace "$NAMESPACE" images tag "$REGISTRY/pause:latest" "$KUBELET_PAUSE_IMAGE"
    echo "Successfully restored pause image."
  else
    echo "Error: Failed to restore pause image ($KUBELET_PAUSE_IMAGE)." >&2
    exit 1
  fi
}

if [ -n "$NERDCTL_PATH" ] && [ -x "$NERDCTL_PATH" ]; then
  echo "nerdctl found. Running nerdctl system prune..."
  # Kubelet이 사용하는 pause 이미지를 제외하고 정리
  nerdctl --namespace "$NAMESPACE" system prune -a -f --filter "image!~=$KUBELET_PAUSE_IMAGE"

  # 정리 후에도 pause 이미지가 존재하는지 확인
  if ! nerdctl --namespace "$NAMESPACE" images --quiet | grep -q "$KUBELET_PAUSE_IMAGE"; then
    ensure_pause_image "nerdctl"
  fi
elif [ -n "$CTR_PATH" ] && [ -x "$CTR_PATH" ]; then
  echo "ctr found. Removing unused images to free up disk space."
  # Kubelet이 사용하는 pause 이미지를 제외한 모든 이미지 목록을 가져와서 삭제
  ctr --namespace "$NAMESPACE" images list -q | grep -v "$KUBELET_PAUSE_IMAGE" | while read -r image; do
    echo "Removing image: $image"
    ctr --namespace "$NAMESPACE" images rm "$image" || echo "Warning: Failed to remove image $image. It might be in use." >&2
  done
  # 정리 후에도 pause 이미지가 존재하는지 확인
  if ! ctr --namespace "$NAMESPACE" images list --quiet | grep -q "$KUBELET_PAUSE_IMAGE"; then
    ensure_pause_image "ctr"
  fi
else
  echo 'Error: Neither nerdctl nor ctr is installed.' >&2
  exit 1
fi

echo "Disk cleanup script completed."
