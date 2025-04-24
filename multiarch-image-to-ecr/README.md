# Multiarch Image to ECR

A tool for managing public image registry images in a private ECR.

## How to use

1. Run the script

```sh
# ECR login
aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <ACCOUNT>.dkr.ecr.<REGION>.amazonaws.com

# Run the script
./multiarch_image_to_ecr.sh <PUBLIC REGISTRY & REPOSITORY> <TAG> <ECR REGISTRY> "IMAGE DOWN ALLOW ACCOUNTS"

# e.g.
./multiarch_image_to_ecr.sh bitnami/nginx 1.27.4 111111111111.dkr.ecr.ap-northeast-2.amazonaws.com "222222222222,333333333333,444444444444"
```

2. Image Migration Pipeline

[Refer to the GitHub Action workflows](./../.github/workflows/multiarch-image-to-ecr.yml)
