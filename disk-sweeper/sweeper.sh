#!/bin/sh

set -x

echo "Starting disk cleanup script..."

if command -v nerdctl &> /dev/null; then
  echo "nerdctl found. Running nerdctl system prune..."
  nerdctl system prune -a -f --namespace=k8s.io 2>/dev/null
  PAUSE_IMAGE=$(nerdctl images --namespace=k8s.io | grep pause | head -1 | awk '{print $3}')

  echo "Tagging pause image: $PAUSE_IMAGE"
  nerdctl --namespace=k8s.io tag $PAUSE_IMAGE localhost/kubernetes/pause:latest
elif command -v crictl &> /dev/null; then
  echo "crictl found. Running crictl cleanup..."
  RUNNING_IMAGES=$(crictl ps --quiet --output json | jq -r '.containers[].imageRef')
  for image in $(crictl images --quiet); do
    if ! echo "$RUNNING_IMAGES" | grep -q "$image"; then
      if crictl inspecti "$image" 2>/dev/null | jq -r '.status.repoTags[]' | grep -qv pause; then
        echo "Removing image: $image"
        crictl rmi "$image"
      fi
    fi
  done
else
  echo 'Neither nerdctl nor crictl is installed.'
fi

echo "Disk cleanup script completed."
