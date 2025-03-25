#!/bin/bash

set -e  # 에러 발생 시 스크립트 종료

# 입력 값 검증
if [ $# -lt 4 ]; then
  echo "Usage: $0 <public_repo> <tag> <ecr_registry> <account1,account2,...>"
  exit 1
fi

# 의존성 확인
for cmd in jq aws docker; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: '$cmd' is not installed. Please install it and try again."
    exit 1
  fi
done

# 입력 값 변수화
PUBLIC_REPO=$1
TAG=$2
ECR_REGISTRY=$3
ACCOUNTS=$4  # 쉼표로 구분된 AWS 계정 리스트

# 퍼블릭 레지스트리 목록 정의
PUBLIC_REGISTRIES=("docker.io" "quay.io" "ghcr.io" "gcr.io" "registry.k8s.io" "k8s.gcr.io" "mcr.microsoft.com" "public.ecr.aws")

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

# ECR 리포지토리 존재 여부 확인 및 생성
REPO_CREATED=false
if ! aws ecr describe-repositories --repository-names "$REPOSITORY" &> /dev/null; then
  echo "ECR repository '$REPOSITORY' does not exist. Creating it..."
  if aws ecr create-repository --repository-name "$REPOSITORY"; then
    REPO_CREATED=true
  else
    echo "Error: Failed to create ECR repository '$REPOSITORY'."
    exit 1
  fi
fi

# 새로 생성된 경우에만 ECR 리포지토리에 권한 추가
if [ "$REPO_CREATED" = true ]; then
  echo "Adding permissions to ECR repository '$REPOSITORY'..."
  ACCOUNTS_ARRAY=(${ACCOUNTS//,/ })
  POLICY=$(cat <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowPullForSpecificAccounts",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          $(for account in "${ACCOUNTS_ARRAY[@]}"; do echo "\"arn:aws:iam::$account:root\""; done | paste -sd "," -)
        ]
      },
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]
    }
  ]
}
EOF
  )
  if ! aws ecr set-repository-policy --repository-name "$REPOSITORY" --policy-text "$POLICY"; then
    echo "Error: Failed to set repository policy for '$REPOSITORY'."
    exit 1
  fi

  # ECR 이미지 보관 정책 설정
  echo "Setting lifecycle policy for ECR repository '$REPOSITORY'..."
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
  if ! aws ecr put-lifecycle-policy --repository-name "$REPOSITORY" --lifecycle-policy-text "$LIFECYCLE_POLICY"; then
    echo "Error: Failed to set lifecycle policy for '$REPOSITORY'."
    exit 1
  fi

  # ECR_REPO_ARN 구성
  # ecr_registry에서 region과 account_id 추출
  REGION=$(echo "$ECR_REGISTRY" | cut -d '.' -f 4)
  ACCOUNT_ID=$(echo "$ECR_REGISTRY" | cut -d '.' -f 1)
  ECR_REPO_ARN="arn:aws:ecr:$REGION:$ACCOUNT_ID:repository/$REPOSITORY"

  aws ecr tag-resource --resource-arn "$ECR_REPO_ARN" --tags Key=Name,Value="$REPOSITORY"
fi

# ECR 이미지 존재 여부 확인
if aws ecr describe-images --repository-name "$REPOSITORY" --image-ids imageTag="$TAG" &> /dev/null; then
  echo "Image '$ECR_REPO_URI' already exists in ECR. Skipping..."
  exit 0
fi

# Dockerfile 생성
cat > Dockerfile <<EOF
FROM ${REGISTRY}/${REPOSITORY}:${TAG}
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