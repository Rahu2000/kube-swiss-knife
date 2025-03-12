# 첫 번째 스테이지: 의존성 설치
FROM --platform=$BUILDPLATFORM python:3.13-slim AS builder

WORKDIR /build

# 필요한 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 가상 환경 생성 - 아키텍처 독립적인 Python 패키지 설치
RUN python -m venv /venv
ENV PATH="/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt

# 두 번째 스테이지: 최종 이미지 빌드
FROM python:3.13-slim

WORKDIR /app

# 첫 번째 스테이지에서 생성된 가상 환경 복사
COPY --from=builder /venv /venv
ENV PATH="/venv/bin:$PATH"

# 애플리케이션 파일 복사
COPY app.py .

# kubectl 설치
ARG TARGETPLATFORM
RUN apt-get update && \
    apt-get install -y curl && \
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"; \
    fi && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 애플리케이션 실행
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]