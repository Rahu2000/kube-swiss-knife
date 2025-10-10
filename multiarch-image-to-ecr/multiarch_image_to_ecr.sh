#!/bin/bash

set -e  # 에러 발생 시 스크립트 종료

# 입력 값 검증
if [ $# -lt 5 ]; then
  echo "Usage: $0 <public_repo> <tag> <ecr_registry> <push_accounts(comma-separated)> <pull_accounts(comma-separated)>"
  exit 1
fi

# 의존성 확인
for cmd in jq aws docker; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: '$cmd' is not installed. Please install it and try again."
    exit 1
  fi
done

# ECR 리포지토리 존재 여부 확인 및 생성 함수
ensure_ecr_repository() {
  local repository="$1"
  if aws ecr describe-repositories --repository-names "$repository" &> /dev/null; then
    # 이미 존재
    return 1
  else
    echo "ECR repository '$repository' does not exist. Creating it..."
    if aws ecr create-repository --repository-name "$repository"; then
      return 0
    else
      echo "Error: Failed to create ECR repository '$repository'."
      exit 1
    fi
  fi
}

# ECR 신규 생성 후 정책/라이프사이클/태그 설정 함수
setup_new_ecr_repository() {
  local repository="$1"
  local push_accounts="$2"
  local pull_accounts="$3"
  local ecr_registry="$4"

  echo "Adding permissions to ECR repository '$repository'..."
  PULL_ARRAY=(${pull_accounts//,/ })
  PUSH_ARRAY=(${push_accounts//,/ })
  POLICY=$(cat <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowPullForSpecificAccounts",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          $(for account in "${PULL_ARRAY[@]}"; do echo "\"arn:aws:iam::$account:root\""; done | paste -sd "," -)
        ]
      },
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeImages"
      ]
    },
    {
      "Sid": "AllowPushForSpecificAccounts",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          $(for account in "${PUSH_ARRAY[@]}"; do echo "\"arn:aws:iam::$account:root\""; done | paste -sd "," -)
        ]
      },
      "Action": [
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetAuthorizationToken"
      ]
    }
  ]
}
EOF
  )
  if ! aws ecr set-repository-policy --repository-name "$repository" --policy-text "$POLICY"; then
    echo "Error: Failed to set repository policy for '$repository'."
    exit 1
  fi

  echo "Setting lifecycle policy for ECR repository '$repository'..."
  LIFECYCLE_POLICY=$(cat <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Retain only the most recent 15 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 15
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
  )
  if ! aws ecr put-lifecycle-policy --repository-name "$repository" --lifecycle-policy-text "$LIFECYCLE_POLICY"; then
    echo "Error: Failed to set lifecycle policy for '$repository'."
    exit 1
  fi

  REGION=$(echo "$ecr_registry" | cut -d '.' -f 4)
  ACCOUNT_ID=$(echo "$ecr_registry" | cut -d '.' -f 1)
  ECR_REPO_ARN="arn:aws:ecr:$REGION:$ACCOUNT_ID:repository/$repository"
  aws ecr tag-resource --resource-arn "$ECR_REPO_ARN" --tags Key=Name,Value="$repository"
}

# 입력 값 변수화
PUBLIC_REPO=$1
TAG=$2
ECR_REGISTRY=$3
PUSH_ACCOUNTS=$4  # 쉼표로 구분된 이미지 푸시 계정 리스트
PULL_ACCOUNTS=$5 # 쉼표로 구분된 이미지 풀 권한 계정 리스트
ALTERNATE_REPO=$6 # (선택 사항) ECR에 저장할 대체 리포지토리 이름

# 퍼블릭 레지스트리 목록 정의
PUBLIC_REGISTRIES=("docker.io" "quay.io" "ghcr.io" "gcr.io" "registry.k8s.io" "k8s.gcr.io" "mcr.microsoft.com" "public.ecr.aws" "cr.fluentbit.io" "oci.registry.io" "oci.external-secrets.io" "ecr-public.aws.com")

# public_repo를 registry와 repository로 분리
if [[ "$PUBLIC_REPO" == *"/"* ]]; then
  # 레지스트리 추출
  REGISTRY=$(echo "$PUBLIC_REPO" | cut -d '/' -f 1)
  REPOSITORY=$(echo "$PUBLIC_REPO" | cut -d '/' -f 2-)

  # REGISTRY가 퍼블릭 레지스트리 목록에 포함되지 않으면 기본값으로 docker.io 설정
  if [[ ! " ${PUBLIC_REGISTRIES[@]} " =~ " ${REGISTRY} " ]]; then
    echo "Warning: '$REGISTRY' is not a recognized public registry. Defaulting to 'docker.io'."
    REGISTRY="docker.io"
    REPOSITORY="$PUBLIC_REPO"
  fi
else
  # 슬래시가 없는 경우, PUBLIC_REPO 전체를 REPOSITORY로 사용하고 REGISTRY는 docker.io로 설정
  REGISTRY="docker.io"
  REPOSITORY="$PUBLIC_REPO"
fi

echo "Registry: $REGISTRY"
echo "Repository: $REPOSITORY"
echo "Processing: Registry=$REGISTRY, Repository=$REPOSITORY, Tag=$TAG"

# ECR_REPO_URI 구성
ECR_REPO_URI="${ECR_REGISTRY}/${REPOSITORY}:${TAG}"

# ECR 리포지토리 존재 여부 확인
REPO_CREATED=false
if ensure_ecr_repository "$REPOSITORY"; then
    REPO_CREATED=true
fi

# ECR이 존재하지 않는 경우 신규 생성 후 ECR 권한 정책/이미지 생명주기 설정
if [ "$REPO_CREATED" = true ]; then
  setup_new_ecr_repository "$REPOSITORY" "$PUSH_ACCOUNTS" "$PULL_ACCOUNTS" "$ECR_REGISTRY"
fi

# ECR에서 Push 이미지 존재 여부 확인
if aws ecr describe-images --repository-name "$REPOSITORY" --image-ids imageTag="$TAG" &> /dev/null; then
  echo "Image '$ECR_REPO_URI' already exists in ECR. Skipping..."
  exit 0
fi

# ALTERNATE_REPO가 존재하는 경우 먼저 ALTERNATE_REPO에서 image pull 시도
FROM_IMAGE="${REGISTRY}/${REPOSITORY}:${TAG}"
if [ -n "$ALTERNATE_REPO" ]; then
  ALTERNATE_PUBLIC_REPO_URI="${REGISTRY}/${ALTERNATE_REPO}:${TAG}"
  if docker pull "$ALTERNATE_PUBLIC_REPO_URI"; then
    FROM_IMAGE="$ALTERNATE_PUBLIC_REPO_URI"
  fi
fi

# Dockerfile 생성
cat > Dockerfile <<EOF
FROM ${FROM_IMAGE}
EOF

# Buildx 빌더 설정
if ! docker buildx inspect mybuilder &> /dev/null; then
  docker buildx create --name mybuilder --use
  docker buildx inspect --bootstrap
fi

# 멀티 아키텍처 이미지 빌드 및 푸시
echo "Building and pushing multi-architecture image to ${ECR_REPO_URI}..."
if ! docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${ECR_REPO_URI} \
  --push .; then
  echo "Error: Failed to build and push the image for $ECR_REPO_URI."
  exit 1
fi

echo "Successfully built and pushed the image to ${ECR_REPO_URI}."