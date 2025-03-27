# Jenkins Webhook Integration

## 1. 개요
이 문서는 Git 저장소와 Jenkins를 Webhook을 통해 연동하여 특정 파일 변경 시 자동으로 파이프라인을 실행하는 방법을 설명합니다.
이를 통해 GitHub, GitLab, 또는 기타 Git 서버에서 Push 이벤트를 기반으로 Jenkins Job을 트리거할 수 있습니다.

---

## 2. Jenkins Webhook 설정 방법

### 2.1 Git 서버에서 Webhook 설정
1. **GitHub** 또는 **GitLab**과 같은 Git 서버의 리포지토리 설정 페이지로 이동합니다.
2. **Webhook** 섹션으로 이동하여 새 Webhook을 추가합니다.
3. **Payload URL**에 Jenkins 서버의 Webhook URL을 입력합니다:
   - 예: `http://<jenkins-server>/github-webhook/`
4. **Content type**을 `application/json`으로 설정합니다.
5. **Trigger events**:
   - Push 이벤트를 선택하여 코드 변경 시 Webhook이 호출되도록 설정합니다.
6. Webhook을 저장합니다.

### 2.2 Jenkins에서 Webhook 플러그인 설치
1. Jenkins 관리 페이지로 이동합니다.
2. **Manage Jenkins > Manage Plugins**로 이동합니다.
3. **Available** 탭에서 다음 플러그인을 검색하여 설치합니다:
   - **GitHub Integration Plugin** (GitHub 사용 시)
   - **Generic Webhook Trigger Plugin** (일반적인 Webhook 사용 시)

---

## 3. Jenkins Job 설정 방법

### 3.1 Job 생성
1. Jenkins 대시보드에서 **New Item**을 클릭합니다.
2. **Pipeline**을 선택하고 Job 이름을 입력한 후 **OK**를 클릭합니다.

### 3.2 Git 저장소 연결
1. **Pipeline** 설정 페이지에서 **Pipeline script from SCM**을 선택합니다.
2. **SCM**을 **Git**으로 설정합니다.
3. **Repository URL**에 Git 저장소 URL을 입력합니다.
4. 필요한 경우 **Credentials**를 추가하여 인증 정보를 설정합니다.

### 3.3 Webhook 트리거 활성화
1. **Build Triggers** 섹션으로 이동합니다.
2. 다음 중 하나를 선택합니다:
   - **GitHub hook trigger for GITScm polling**: GitHub Webhook을 사용할 경우.
   - **Generic Webhook Trigger**: 일반적인 Webhook을 사용할 경우.
3. 설정을 저장합니다.

---

### 3.4 Jenkinsfile 작성
Jenkins Job에서 사용할 `Jenkinsfile`을 작성합니다. 아래는 Webhook 기반으로 특정 파일 변경을 감지하고 작업을 실행하는 예시입니다:

```groovy
pipeline {
    agent any

    triggers {
        pollSCM('H/5 * * * *') // 5분마다 Git 변경 사항 확인
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out code...'
                checkout scm
            }
        }

        stage('Validate Changed Files') {
            steps {
                script {
                    def changedFiles = sh(
                        script: "git diff-tree --no-commit-id --name-only -r $GIT_COMMIT",
                        returnStdout: true
                    ).trim().split("\n")

                    if (!changedFiles.contains("multiarch-image-to-ecr/asserts/images.txt")) {
                        echo "No changes in images.txt. Skipping pipeline."
                        currentBuild.result = 'SUCCESS'
                        return
                    }
                }
            }
        }

        stage('Process Images') {
            steps {
                echo 'Processing images...'
                sh '''
                INPUT_FILE="multiarch-image-to-ecr/asserts/images.txt"
                while IFS= read -r line || [ -n "$line" ]; do
                    PUBLIC_REPO=$(echo "$line" | cut -d ',' -f 1)
                    TAG=$(echo "$line" | cut -d ',' -f 2)
                    [multiarch_image_to_ecr.sh](http://_vscodecontentref_/1) "$PUBLIC_REPO" "$TAG" "$ECR_REGISTRY" "$ACCOUNTS"
                done < "$INPUT_FILE"
                '''
            }
        }
    }
}