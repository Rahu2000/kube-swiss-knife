# Multiarch Image to ECR

A tool for managing public image registry images in a private ECR.

## directory

```txt
.
├── Jenkinsfile                  # Jenkins 파이프라인 정의
├── multiarch_image_to_ecr.sh    # 이미지 복사 및 ECR 업로드 스크립트
├── README.md                    # 프로젝트 설명 파일
├── asserts/
│   └── share-images.txt         # 공유 ECR로 복사할 이미지 목록
├── doc/
│   └── Jenkins.md               # Jenkins 관련 문서
```

- `.github/workflows/` : GitHub Actions 워크플로우 파일 디렉터리
- `multiarch_image_to_ecr.sh` : 이미지 복사 및 ECR 업로드 자동화 스크립트
- `asserts/share-images.txt` : 복사 대상 이미지 목록(레포, 태그, 대체 레포)
- `doc/Jenkins.md` : Jenkins 파이프라인 관련 문서

## multiarch_image_to_ecr.sh

- Public Registry의 이미지를 지정한 ECR로 복사(미러링)하는 자동화 스크립트입니다.
- multi-arch 이미지를 지원합니다(amd64, arm64 등).
- ECR 리포지토리가 없으면 자동으로 생성합니다.
   - ECR 리포지토리 정책 및 라이프사이클 정책을 자동으로 설정합니다.  (기본 정책: Repository 별 최대 30개 이미지 보관)
   - ECR 복사 대상 계정(푸시/풀 권한) 설정을 지원합니다.
- 이미지 복사 시 Alternate Repo(대체 레포)도 지원합니다. (bitnami의 경우 오래된 버전의 이미지는 대체 레포에서만 다운로드 가능)
- 실패한 작업은 로그로 남기고, 전체 작업 완료 후 결과를 출력합니다.

## How to use

1. `asserts/*-images.txt` 파일에 이미지를 추가하거나, 기존 이미지의 버전을 변경합니다.
2. 변경 사항을 커밋(push)하면 GitHub Actions가 자동으로 실행되어 이미지를 ECR로 복사합니다.
   - 수동 실행이 필요한 경우, GitHub Actions에서 직접 워크플로우를 실행할 수도 있습니다.
3. 자세한 워크플로우 내용은 [`.github/workflows/multiarch-image-to-share-ecr.yml`](.github/workflows/multiarch-image-to-share-ecr.yml) 파일을 참고하세요.

## 이미지 목록 (asserts/share-images.txt)

| Public Registry/Repo | Tag | Alternate Repo (옵션) |
|---------------------|-----|----------------------|
| cr.fluentbit.io/fluent/fluent-bit | 3.2.8 |  |
| docker.io/bitnami/kubectl | latest | bitnamilegacy/kubectl |
| docker.io/bitnami/mariadb | 10.11.4-debian-11-r0 | bitnamilegacy/mariadb |
| docker.io/bitnami/postgres-exporter | 0.11.1-debian-11-r46 | bitnamilegacy/postgres-exporter |
| docker.io/bitnami/postgresql | 15.1.0-debian-11-r20 | bitnamilegacy/postgresql |
| docker.io/bitnami/rabbitmq | 3.12.0-debian-11-r0 | bitnamilegacy/rabbitmq |
| docker.io/bitnami/redis | 6.2.16 | bitnamilegacy/redis |
| docker.io/busybox | 1.36 |  |
| docker.io/flowiseai/flowise | 2.1.2 |  |
| docker.io/fluent/fluent-bit | 3.1 |  |
| ... | ... | ... |

- Alternate Repo : Public Registry/Repo가 변경되었거나 해당 Tag가 더 이상 존재하지 않는 경우, 과거에 사용하던 Image Registry/Repo를 명시합니다. 이 레포지토리에서 이미지를 가져올 수 있습니다.

> 전체 목록은 [asserts/share-images.txt](./asserts/share-images.txt) 파일을 참고하세요.

## GitHub Actions 변수 입력 항목

|  변수명 | 설명 |
|--------|------|
| ECR_ASSUME_ROLE | Assume Role에 사용할 교차계정의 AWS IAM Role ARN |
| SHARE_ECR_REGISTRY | Share 계정의 ECR 레지스트리 주소 |
| SHARE_ECR_PUSH_ACCOUNTS | ECR에 이미지를 푸시할 수 있는 AWS 계정 목록(쉼표 구분) |
| SHARE_ECR_PULL_ACCOUNTS | ECR에서 이미지를 풀할 수 있는 AWS 계정 목록(쉼표 구분) |

> 각 변수는 GitHub Repository Settings의 Variables(환경 변수)로 등록하여 사용합니다.

