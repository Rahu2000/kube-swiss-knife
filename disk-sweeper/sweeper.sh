#!/bin/sh

set -x

echo "Starting disk cleanup script..."

NERDCTL_PATH=$(command -v nerdctl 2>/dev/null)
CTR_PATH=$(command -v ctr 2>/dev/null)
if [ -n "$NERDCTL_PATH" ] && [ -x "$NERDCTL_PATH" ]; then
  echo "nerdctl found. Running nerdctl system prune..."
  nerdctl system prune -a -f --namespace=k8s.io 2>/dev/null

  PAUSE_IMAGE=$(nerdctl images | grep pause | head -1 | awk '{print $3}')

  if [ -z "$PAUSE_IMAGE" ]; then
    nerdctl pull "registry.k8s.io/pause:latest"
    PAUSE_IMAGE=$(nerdctl images | grep pause | head -1 | awk '{print $3}')
  fi

  echo "Tagging pause image: $PAUSE_IMAGE"
  nerdctl --namespace=k8s.io tag "$PAUSE_IMAGE" localhost/kubernetes/pause:latest
elif [ -n "$CTR_PATH" ] && [ -x "$CTR_PATH" ]; then
  echo "ctr found. Disk 공간 확보를 위해 불필요한 컨테이너와 이미지를 삭제합니다."
  # 모든 이미지 삭제
  ctr --namespace k8s.io images list -q | xargs -r ctr --namespace k8s.io images remove
  # pause 이미지 다운로드 및 태깅
  ctr images pull registry.k8s.io/pause:latest
  ctr images tag registry.k8s.io/pause:latest localhost/kubernetes/pause:latest
else
  echo 'Neither nerdctl nor ctr is installed.'
fi

echo "Disk cleanup script completed."
