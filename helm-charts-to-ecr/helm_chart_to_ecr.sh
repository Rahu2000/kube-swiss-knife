#!/bin/bash

# This script exports a Helm chart from a public repository and pushes it to ECR.

set -e

# Input arguments
HELM_REPO=$1
CHART_PATH=$2
CHART_VERSION=$3
AWS_REGION=${4:-"us-east-1"} # Default AWS region if not provided
ECR_REPO=$5
ALLOWED_ACCOUNTS=$6 # Optional allowed accounts

if [[ -z "$HELM_REPO" || -z "$CHART_PATH" || -z "$CHART_VERSION" || -z "$ECR_REPO" ]]; then
  echo "Usage: $0 <helm_repo> <chart_path> <chart_version> [aws_region] <ecr_repo> [allowed_accounts]"
  exit 1
fi

# Extract repository name
REPOSITORY=$(basename "$ECR_REPO")/$CHART_PATH

# Step 1: Check and create ECR repository
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

# Add permissions if repository was created
if [ "$REPO_CREATED" = true ] && [[ -n "$ALLOWED_ACCOUNTS" ]]; then
  echo "Adding read-only permissions to ECR repository '$REPOSITORY' for allowed accounts..."
  ACCOUNTS_ARRAY=(${ALLOWED_ACCOUNTS//,/ })
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
fi

# Step 2: Check if chart version exists
echo "Checking if chart version already exists in ECR and Helm repository..."

# Check if the chart version exists in ECR
if aws ecr describe-images --repository-name "$REPOSITORY" --image-ids imageTag="$CHART_VERSION" &> /dev/null; then
  echo "Chart version $CHART_VERSION already exists in ECR. Skipping push."
  exit 0
fi

# Check if the chart version exists in the Helm repository
if ! helm search repo temp-repo/"$CHART_PATH" --version "$CHART_VERSION" &> /dev/null; then
  echo "Error: Chart version $CHART_VERSION does not exist in the Helm repository."
  exit 1
fi

# Step 3: Add the Helm repository
echo "Adding Helm repository: $HELM_REPO"
helm repo add temp-repo "$HELM_REPO"
helm repo update

# Step 4: Pull the Helm chart
echo "Pulling Helm chart: $CHART_PATH, version: $CHART_VERSION"
TEMP_DIR=$(mktemp -d)
helm pull temp-repo/"$CHART_PATH" --version "$CHART_VERSION" --untar --destination "$TEMP_DIR"

# Step 5: Package the chart into a tarball
echo "Packaging Helm chart into tarball"
CHART_TARBALL="${TEMP_DIR}/${CHART_PATH}-${CHART_VERSION}.tgz"
helm package "$TEMP_DIR/$CHART_PATH" --version "$CHART_VERSION" -d "$TEMP_DIR"

# Step 6: Push the chart to ECR
echo "Pushing Helm chart to ECR: $ECR_REPO"
helm push "$CHART_TARBALL" oci://"$ECR_REPO"

# Step 7: Cleanup
echo "Cleaning up temporary files"
rm -rf "$TEMP_DIR"

echo "Helm chart successfully pushed to ECR: $ECR_REPO"