# Helm Charts to ECR

## 1. 개요
`helm_chart_to_ecr.sh` 스크립트는 Helm Chart를 지정된 Helm Chart 저장소에서 다운로드한 후, Amazon ECR(Elastic Container Registry)에 저장하는 자동화 도구입니다.
이 스크립트를 사용하면 Helm Chart를 ECR에 저장하고, Kubernetes 클러스터에서 이를 활용할 수 있습니다.

---

## 2. `helm_chart_to_ecr.sh` 사용법

### 스크립트 실행 방법

```bash
./helm_chart_to_ecr.sh <helm_repo> <chart_path> <chart_version> [aws_region] <ecr_repo> [allowed_accounts]
```

### 입력값 설명

| 항목              | 설명                                                                                     |
|-------------------|------------------------------------------------------------------------------------------|
| `<helm_repo>`     | Helm Chart 저장소 URL (예: `https://charts.bitnami.com/bitnami`)                         |
| `<chart_path>`    | Helm Chart 이름 또는 경로 (예: `nginx`)                                                  |
| `<chart_version>` | Helm Chart 버전 (예: `13.2.0`)                                                          |
| `[aws_region]`    | AWS 리전 (기본값: `us-east-1`)                                                          |
| `<ecr_repo>`      | Amazon ECR 레지스트리 URL (예: `123456789012.dkr.ecr.us-east-1.amazonaws.com/my-helm-charts`) |
| `[allowed_accounts]` | (선택) ECR에서 Chart를 읽을 수 있는 AWS 계정 ID 목록 (쉼표로 구분)                     |

### 예시
```bash
./helm_chart_to_ecr.sh https://charts.bitnami.com/bitnami nginx 13.2.0 us-east-1 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-helm-charts "123456789012,987654321098"
```

---

## 3. ArgoCD에서 Helm Chart 사용법

### ECR 인증 설정
ArgoCD가 ECR에서 Helm Chart를 다운로드하려면 인증이 필요합니다. 아래 방법 중 하나를 선택하세요:

#### (1) IAM Role for Service Account (IRSA) 사용

1. ArgoCD가 사용하는 Service Account에 IAM Role을 연결합니다.
2. IAM Role에 다음 권한을 추가합니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    }
  ]
}
```

#### (2) Helm 레지스트리 인증 정보 설정

1. AWS CLI를 사용하여 ECR 인증 토큰을 생성합니다:

```bash
aws ecr get-login-password --region <AWS_REGION>
```

2. ArgoCD의 Repositories 설정에 인증 정보를 추가합니다:

```yaml
repositories:
  - name: my-ecr-helm-repo
    type: helm
    url: oci://<ECR_REGISTRY_URL>
    username: AWS
    password: <ECR_AUTH_TOKEN>
```

### (3) ArgoCD Application 생성
Helm Chart를 사용하는 ArgoCD Application을 생성합니다.

#### 예시

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-helm-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: oci://<ECR_REGISTRY_URL>
    chart: <CHART_PATH>
    targetRevision: <CHART_VERSION>
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

| 항목                | 설명                                                                                   |
|---------------------|----------------------------------------------------------------------------------------|
| `<ECR_REGISTRY_URL>`| Amazon ECR 레지스트리 URL (예: `123456789012.dkr.ecr.us-east-1.amazonaws.com/my-helm-charts`) |
| `<CHART_PATH>`      | Helm Chart 이름 (예: `nginx`)                                                          |
| `<CHART_VERSION>`   | Helm Chart 버전 (예: `13.2.0`)                                                        |

---

## 4. 로컬 환경에서 ECR의 Chart 검증

### 4.1 ECR 인증
Helm CLI가 ECR에 접근하려면 인증이 필요합니다. 다음 명령어를 실행하여 ECR에 로그인합니다:

```bash
export HELM_EXPERIMENTAL_OCI=1
aws ecr get-login-password --region <AWS_REGION> | helm registry login --username AWS --password-stdin <ECR_REGISTRY_URL>
```

| 항목                | 설명                                                                                   |
|---------------------|----------------------------------------------------------------------------------------|
| `<AWS_REGION>`      | ECR이 위치한 AWS 리전 (예: `ap-northeast-2`)                                           |
| `<ECR_REGISTRY_URL>`| Amazon ECR 레지스트리 URL (예: `123456789012.dkr.ecr.us-east-1.amazonaws.com`)          |

### 4.2 Chart Pull 및 설치
1. ECR에서 Chart를 다운로드합니다:
   ```bash
   helm pull oci://<ECR_REGISTRY_URL>/<CHART_PATH> --version <CHART_VERSION>
   ```

   예:
   ```bash
   helm pull oci://123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/helm-charts/aws-load-balancer-controller --version 1.10.1
   ```

2. 다운로드한 Chart를 설치합니다:
   ```bash
   helm install <RELEASE_NAME> <CHART_TARBALL>
   ```

   예:
   ```bash
   helm install my-aws-lb-controller aws-load-balancer-controller-1.10.1.tgz
   ```

---

> **⚠️ WARNING**
> Helm Charts에 포함된 CRD(Custom Resource Definition)는 클러스터 전역 리소스이며, Chart 배포 전에 반드시 설치되어야 합니다.
> - CRD가 Chart의 `crds/` 디렉토리에 포함된 경우, Helm이 자동으로 처리합니다.
> - CRD가 Chart에 포함되지 않은 경우, CRD를 별도로 설치해야 하며, 이를 자동화하려면 추가적인 스크립트나 워크플로우가 필요합니다.
> - CRD가 분리 보관된 경우, 별도의 Git repository에서 관리하거나, Chart 배포 전에 수동으로 설치해야 합니다.

---

## 참고

- [Helm 공식 문서](https://helm.sh/docs/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [AWS ECR 공식 문서](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)