#!/bin/bash

function usage()
{
    echo
    echo Usage:
    echo "./config.sh [subnet]"
    echo "  subnet: (optional) Docker monitoring network subnet. Example: 172.30.0.0/16"
    echo "          If omitted, subnet is automatically assigned."
    echo
}

# failed 함수 추가
function failed() {
    echo "Failed: $1" >&2
    exit 1
}

user_id=`id -u`

# systemctl must run as sudo
# this script is a convenience wrapper around systemctl
if [ $user_id -ne 0 ]; then
    echo "Must run as sudo"
    exit 1
fi

# Docker 명령어 확인
if ! command -v docker &> /dev/null; then
    echo "Docker could not be found"
    exit 1
fi

# Docker Compose 명령어 체크 및 설치 (docker-compose 우선, 없으면 docker compose, 둘 다 없으면 설치)
if ! command -v docker-compose &> /dev/null && ! docker --help | grep -q ' compose '; then
    echo "Docker Compose could not be found"
    echo "Installing Docker Compose plugin..."
    sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose
    sudo chmod +x /usr/bin/docker-compose
fi

# Docker monitoring network 생성 (IP 인자 있으면 명시적, 없으면 자동)
NETWORK_SUBNET="$1"
if docker network ls | grep -q monitoring; then
    echo "Monitoring network already exists"
else
    if [ -n "$NETWORK_SUBNET" ]; then
        docker network create --driver bridge --subnet "$NETWORK_SUBNET" monitoring || failed "failed to create monitoring network"
    else
        docker network create --driver bridge monitoring || failed "failed to create monitoring network"
    fi
fi

cp ./bin/monitoring.svc.sh.template ./svc.sh || failed "failed to copy svc.sh"
chown $(id -u):$(id -g) ./svc.sh || failed "failed to set owner for svc.sh"
chmod 755 ./svc.sh || failed "failed to set permission for svc.sh"

# Run svc.sh to register the monitoring system as a systemd service
echo "To register the monitoring system as a systemd service, run:"
echo "  sudo ./svc.sh [install|start|stop|status|uninstall]"
