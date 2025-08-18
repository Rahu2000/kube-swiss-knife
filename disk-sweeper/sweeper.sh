#!/bin/sh

set -x

echo "Starting disk cleanup script..."

NERDCTL_PATH=$(command -v nerdctl 2>/dev/null)
CTR_PATH=$(command -v ctr 2>/dev/null)
NAMESPACE=${1:-k8s.io}

if [ -n "$NERDCTL_PATH" ] && [ -x "$NERDCTL_PATH" ]; then
  echo "nerdctl found. Running nerdctl system prune..."
  nerdctl system prune -a -f --namespace=$NAMESPACE 2>/dev/null

  LOCALHOST_PAUSE_IMAGE=$(nerdctl images --namespace=$NAMESPACE | grep localhost/kubernetes/pause | head -1 | awk '{print $3}')

  if [ -z "$LOCALHOST_PAUSE_IMAGE" ]; then
    PAUSE_IMAGE=$(nerdctl images --namespace=$NAMESPACE | grep pause | head -1 | awk '{print $3}')
    if [ -z "$PAUSE_IMAGE" ]; then
      nerdctl pull --namespace=$NAMESPACE "registry.k8s.io/pause:latest"
      nerdctl tag --namespace=$NAMESPACE "registry.k8s.io/pause:latest" "localhost/kubernetes/pause:latest"
    else
      nerdctl tag --namespace=$NAMESPACE "$PAUSE_IMAGE" "localhost/kubernetes/pause:latest"
    fi
    echo "Tagging pause image: localhost/kubernetes/pause"
  fi
elif [ -n "$CTR_PATH" ] && [ -x "$CTR_PATH" ]; then
  echo "ctr found. Disk 공간 확보를 위해 불필요한 컨테이너와 이미지를 삭제합니다."
  # pause 이미지를 제외한 모든 이미지 삭제
  for image in $(ctr --namespace $NAMESPACE images list -q); do
    if ! echo "$image" | grep -q "pause"; then
      ctr --namespace $NAMESPACE images remove "$image"
    fi
  done

  # pause 이미지가 없으면 다운로드 및 태깅
  if ! ctr --namespace $NAMESPACE images list | grep -q pause; then
    ctr images pull registry.k8s.io/pause:latest
    ctr images tag registry.k8s.io/pause:latest localhost/kubernetes/pause:latest
  fi
else
  echo 'Neither nerdctl nor ctr is installed.'
fi

echo "Disk cleanup script completed."
