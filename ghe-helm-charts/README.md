# ghe-helm-charts

폐쇄망 Kubernetes 환경을 위한 Helm 차트 저장소입니다. 다양한 오픈소스 및 커스텀 Helm 차트를 관리하며, 배포 및 운영 자동화를 지원합니다.

## 디렉터리 구조

```txt
ghe-helm-charts/
├── charts/    # Helm 차트 디렉터리
├── asserts/   # 차트 등록 파일(helm-charts.txt 등)
├── docs/      # Helm charts repository (index.yaml, chart의 tgz 파일 관리)
└── README.md  # 저장소 소개 및 안내
```

## 신규 차트 및 기존 차트 버전 추가 사용 방법

`asserts/helm-charts.txt`에 차트를 추가하거나 버전을 변경하면 `.github/workflows/ghe-helm-charts.yml` 파이프라인을 통해 차트가 자동으로 배포됩니다.

### asserts/helm-charts.txt 파일 형식

`helm-charts.txt`는 CSV 형식으로, 각 행은 아래와 같이 구성됩니다:

```txt
public helm chart repo,chart name,chart version
```

예시:

```csv
https://charts.jetstack.io,cert-manager,v1.12.2
https://prometheus-community.github.io/helm-charts,kube-prometheus-stack,56.7.2
https://argoproj.github.io/argo-helm,argo-rollouts,2.32.3
```

## 차트 설치 방법

```bash
helm repo add charts https://YOUR-GITHUB/pages/Tech/ghe-helm-charts/ \

# Repository 업데이트
helm repo update charts

# 사용 가능한 차트 검색
helm search repo charts

# 차트 설치
helm install my-release charts/[chart-name]
```

## 권장 설정

### Github Enterprise 설정

`Pages`: 활성화

`Public Pages`: 활성화

Helm 클라이언트는 chart 저장소의 index.yaml 및 .tgz 파일을 직접 다운로드해야 하므로, 저장소가 "Private" 상태이거나 인증이 필요한 경우 Helm repo로 사용할 수 없습니다.</br>
"Public Pages"를 활성화하면 누구나(또는 조직 내 모든 사용자) 해당 chart repository에 접근할 수 있어 Helm repo로 정상 동작합니다.

### Github Pages 설정

`Pages HOME`: main 브랜치의 /docs

Pages는 다음의 이유로 설정합니다.

- **간편한 배포**: GitHub Pages는 정적 파일(예: index.yaml, .tgz chart 파일)을 웹에서 쉽게 호스팅할 수 있습니다. 별도의 서버나 인프라 없이도 Helm 클라이언트가 접근 가능한 HTTP(S) 저장소를 빠르게 구축할 수 있습니다.
- **Helm 표준 지원**: Helm은 chart repository로 HTTP(S)로 접근 가능한 경로를 요구합니다. GitHub Pages는 HTTPS를 기본 제공하므로, Helm repo로 바로 활용할 수 있습니다.
