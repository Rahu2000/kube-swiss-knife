# EC2 기반 Docker Container 서비스 모니터링

Systemd에 docker 서비스를 모니터링하는 서비스를 등록하여 자동 관리, 재시작, 로그 통합, 부팅 시 자동 실행 등 운영 안정성 향상을 목적으로 합니다.

## 서비스 등록

```sh
# 파일을 서버에 복사
cd /opt
git clone https://github.com/Rahu2000/kube-swiss-knife.git

cd docker-monitoring
sudo chmod +x ./config.sh

# 서비스 등록 설정
sudo ./config.sh

# 만약 네트워크를 추가 할 수 없다는 메시지가 출력될 경우
# sudo ./config.sh 172.20.0.0/16 # subnet 대역은 변경 가능

# 서비스 등록
sudo ./svc install

# 모니터링 서비스 시작
sudo ./svc start
```

## 서비스 확인

```sh
# systemd 상태 조회
sudo ./svc status

# docker ps 조회 시 node-exporter, cadvisor 동작 여부 확인
docker ps
```

## 모니터링 구성

- Security Group 변경

서비스를 설치한 EC2 서버의 SG의 인바운드에 다음 포트 규칙을 추가한다.
Port:
  9100
  8080

- Endpoint, Service, MonitoringService 추가

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: <EC2 NAME>
  namespace: monitoring
  labels:
    app: <EC2 NAME>
subsets:
  - addresses:
    - ip: <EC2 IP>
    ports:
      - name: node-exporter
        port: 9100
        protocol: TCP
      - name: cadvisor
        port: 8080
        protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: <EC2 NAME>
  namespace: monitoring
  labels:
    app: <EC2 NAME>
spec:
  ports:
  - name: node-exporter
    protocol: TCP
    port: 9100
    targetPort: 9100
  - name: cadvisor
    protocol: TCP
    port: 8080
    targetPort: 8080
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <EC2 NAME>
  namespace: monitoring
  labels:
    app: <EC2 NAME>
    release: kube-prometheus
spec:
  endpoints:
  - path: /metrics
    port: node-exporter
    interval: 15s
    honorLabels: true
    relabelings:
    - action: replace
      replacement: $1
      regex: ([^:]+):.+
      sourceLabels:
      - __address__
      targetLabel: instance
  - path: /metrics
    port: cadvisor
    interval: 15s
    honorLabels: true
    relabelings:
    - action: replace
      replacement: $1
      regex: ([^:]+):.+
      sourceLabels:
      - __address__
      targetLabel: instance
  jobLabel: <EC2 NAME>
  selector:
    matchLabels:
      app: <EC2 NAME>
```

## 서비스 삭제

```sh
sudo ./svc stop
sudo ./svc uninstall
```
