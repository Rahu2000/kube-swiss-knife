# disk-sweeper

[![Build and Push Docker Image to Docker Hub](https://github.com/Rahu2000/kube-swiss-knife/actions/workflows/build-disk-sweeper.yaml/badge.svg)](https://github.com/Rahu2000/kube-swiss-knife/actions/workflows/build-disk-sweeper.yaml)

A tool to clean up disk space on Kubernetes nodes using nerdctl or crictl.

`disk-sweeper` is a project designed to clean up disk space on Kubernetes nodes. This tool helps to free up disk space by removing unnecessary files and data, optimizing system performance. `disk-sweeper` runs automatically in a Kubernetes environment and performs disk cleanup tasks based on configured rules.

## 이미지 빌드

```sh
# 이미지 빌드 및 푸시 예제
./build.sh <REPO_IMAGE> <TAG> --namespace [NAMESPACE] --registry [REGISTRY]

# 예시
./build.sh my-repo/disk-sweeper v1.0.0
```

### Private Registry를 적용한 이미지 빌드

```sh
# Private Registry를 사용하는 경우 e.g AWS ECR
# 1. ECR 로그인
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com

# 2. 빌드 및 푸시
./build.sh my-repo/disk-sweeper v1.0.0 --registry <account_id>.dkr.ecr.<region>.amazonaws.com
```

## kubernetes 배포

[CronJob 배포 예제](../examples/diks-sweeper/disk-sweeper.yaml)
