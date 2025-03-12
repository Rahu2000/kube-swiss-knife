# kube-maintainer
kube maintainer

![Coverage](../.github/badges/kube-maintainer/coverage-badge.svg)

[![Build and Push Docker Image to Docker Hub or ECR](https://github.com/Rahu2000/kube-swiss-knife/actions/workflows/build-kube-maintainer.yaml/badge.svg)](https://github.com/Rahu2000/kube-swiss-knife/actions/workflows/build-kube-maintainer.yaml)

## 프로젝트 설정

### Python 가상 환경 구성

1. Python 가상 환경 생성

   ```sh
   python3 -m venv venv
   ```

2. 가상 환경 활성화

   - macOS/Linux:

     ```sh
     source venv/bin/activate
     ```

   - Windows:

     ```sh
     .\venv\Scripts\activate
     ```

3. 필요한 패키지 설치

   ```sh
   pip install -r requirements.txt
   ```

### 테스트 실행

1. 가상 환경 활성화 (위의 가상 환경 구성 단계 참고)

2. `unittest`를 사용하여 테스트 실행

   ```sh
   python -m unittest discover -s tests
   ```

이 명령어는 `tests` 디렉토리에서 테스트 파일을 자동으로 검색하고 실행합니다.

## 프로젝트 설명

이 프로젝트는 Kubernetes 클러스터에서 플러그인 배포 및 삭제를 관리하는 Flask 애플리케이션입니다. 주요 기능은 다음과 같습니다:

- `/healthz`: 애플리케이션의 상태를 확인하는 헬스 체크 엔드포인트
- `/maintainer/plugin/deploy`: 플러그인을 배포하는 엔드포인트
- `/maintainer/plugin/delete`: 플러그인을 삭제하는 엔드포인트

## 환경 변수

- `NAMESPACE`: 네임스페이스 이름 (기본값: `default`)
- `AUTO_DELETE`: 배포 후 자동 삭제 여부 (기본값: `false`)
- `SLEEP_TIME`: 자동 삭제까지 대기할 시간 (초, 기본값: `600`)
- `LOG_LEVEL`: 로그 수준 (기본값: `INFO`)

## 입력 값

- `config_category` (필수): 리소스 타입 (예: `deployment`, `service`)
- `namespace`: 네임스페이스 이름 (기본값: `default`)
- `auto_delete`: 배포 후 자동 삭제 여부 (기본값: `false`)
- `services`: 쉼표로 구분된 문자열 배열 (예: `service1,service2`)
- `sleep_time`: 자동 삭제까지 대기할 시간 (초, 기본값: `600`)

## kubernetes 배포

[helm chart 배포](https://github.com/Rahu2000/charts/tree/main/charts/kube-maintainer)
