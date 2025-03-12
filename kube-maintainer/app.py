from flask import Flask, request, jsonify
import os
import subprocess
import glob
import threading
import time
import logging
import sys

app = Flask(__name__)

# 로그 수준 설정
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
logging.basicConfig(stream=sys.stdout, level=getattr(logging, log_level, logging.INFO), format='%(asctime)s - %(levelname)s - %(message)s')

"""
환경 변수
- NAMESPACE: 네임스페이스 이름 (기본값: default)
- AUTO_DELETE: 배포 후 자동 삭제 여부 (기본값: false)
- SLEEP_TIME: 자동 삭제까지 대기할 시간 (초, 기본값: 600)
- LOG_LEVEL: 로그 수준 (기본값: INFO)

입력 값
- config_category (필수): 리소스 타입 (예: deployment, service)
- namespace: 네임스페이스 이름 (기본값: default)
- auto_delete: 배포 후 자동 삭제 여부 (기본값: false)
- services: 쉼표로 구분된 문자열 배열 (예: service1,service2)
- sleep_time: 자동 삭제까지 대기할 시간 (초, 기본값: 600)
"""

def get_env_var(key, default=None):
    """
    환경 변수를 대소문자 구분 없이 가져오는 함수.
    """
    for k, v in os.environ.items():
        if k.lower() == key.lower():
            return v
    return default

def get_request_var(data, key, default=None):
    """
    요청 데이터를 대소문자 구분 없이 가져오는 함수.
    """
    for k, v in data.items():
        if k.lower() == key.lower():
            return v
    return default

def delete_yaml_files(namespace, yaml_files, sleep_time):
    """
    지정된 시간 동안 대기한 후, 주어진 네임스페이스에서 YAML 파일을 삭제합니다.
    """
    time.sleep(sleep_time)  # 외부에서 주입된 시간 대기
    errors = []
    deleted_files = []
    for yaml_file in yaml_files:
        # kubectl delete 명령어 실행
        result = subprocess.run(['kubectl', 'delete', '-f', yaml_file, '-n', namespace], capture_output=True, text=True)
        if result.returncode != 0:
            errors.append({'file': yaml_file, 'error': result.stderr})
        else:
            deleted_files.append(yaml_file)
    logging.info(f'Deleted files: {deleted_files}')
    return errors, deleted_files

@app.before_request
def log_request_info():
    if request.path == '/healthz':
        if logging.getLogger().isEnabledFor(logging.DEBUG):
            logging.debug(f'Request from {request.remote_addr} to {request.url} with data: {request.json}')
    else:
        logging.info(f'Request from {request.remote_addr} to {request.url} with data: {request.json}')

@app.after_request
def log_response_info(response):
    if request.path == '/healthz':
        if logging.getLogger().isEnabledFor(logging.DEBUG):
            logging.debug(f'Response status: {response.status}')
    else:
        logging.info(f'Response status: {response.status}')
    return response

@app.route('/healthz', methods=['GET'])
def health_check():
    """
    애플리케이션의 상태를 확인하는 헬스 체크 엔드포인트.
    """
    logging.debug('Health check endpoint called')
    return jsonify({'status': 'healthy'}), 200

@app.route('/maintainer/plugin/deploy', methods=['POST'])
def deploy():
    """
    주어진 네임스페이스에 YAML 파일을 배포하는 엔드포인트.
    """
    try:
        logging.info('Deploy endpoint called')
        data = request.json or {}

        # 요청에서 config_category 값을 가져옴
        config_category = get_request_var(data, 'config_category')
        if not config_category:
            return jsonify({'message': 'config_category is required'}), 400
        config_category = config_category.lower()

        # 요청에서 namespace 값을 가져오고, 없으면 환경 변수에서 가져옴
        namespace = get_request_var(data, 'namespace', get_env_var('NAMESPACE', 'default'))

        # 요청에서 auto_delete 값을 가져오고, 없으면 환경 변수에서 가져옴
        auto_delete = get_request_var(data, 'auto_delete', get_env_var('AUTO_DELETE', 'false')).lower() == 'true'

        # 요청에서 sleep_time 값을 가져오고, 없으면 환경 변수에서 가져옴
        sleep_time = int(get_request_var(data, 'sleep_time', get_env_var('SLEEP_TIME', 600)))

        # 요청에서 services 값을 가져옴
        services = get_request_var(data, 'services')
        if services:
            services = [service.strip() for service in services.split(',')]
            yaml_files = [f'/config/{config_category}/{service}.yaml' for service in services]
            # 파일 존재 여부 확인
            missing_files = [yaml_file for yaml_file in yaml_files if not os.path.exists(yaml_file)]
            if missing_files:
                return jsonify({'message': 'Some files are missing', 'missing_files': missing_files}), 400
        else:
            # 마운트된 경로의 모든 YAML 파일을 가져옴
            yaml_files = glob.glob(f'/config/{config_category}/*.yaml')

        errors = []
        applied_files = []
        for yaml_file in yaml_files:
            # kubectl apply 명령어 실행
            result = subprocess.run(['kubectl', 'apply', '-f', yaml_file, '-n', namespace], capture_output=True, text=True)
            if result.returncode != 0:
                errors.append({'file': yaml_file, 'error': result.stderr})
            else:
                applied_files.append(yaml_file)

        if auto_delete:
            # sleep_time 후 YAML 파일 삭제를 위한 스레드 시작
            delete_thread = threading.Thread(target=delete_yaml_files, args=(namespace, yaml_files, sleep_time))
            delete_thread.start()
            logging.info(f'Started delete thread with sleep time: {sleep_time} seconds')

        if errors:
            logging.info(f'Deployment completed with errors: {errors}')
            return jsonify({
                'message': 'Deployment completed with errors',
                'errors': errors,
                'applied_files_count': len(applied_files),
                'applied_files': applied_files
            }), 207  # 207: Multi-Status
        logging.info(f'Deployment successful: {applied_files}')
        return jsonify({
            'message': 'Deployment successful',
            'applied_files_count': len(applied_files),
            'applied_files': applied_files
        }), 200
    except Exception as e:
        logging.error(f'An error occurred during deployment: {str(e)}')
        return jsonify({'message': 'An error occurred', 'error': str(e)}), 500

@app.route('/maintainer/plugin/delete', methods=['POST'])
def delete():
    """
    주어진 네임스페이스에서 YAML 파일을 삭제하는 엔드포인트.
    """
    try:
        logging.info('Delete endpoint called')
        data = request.json or {}

        # 요청에서 config_category 값을 가져옴
        config_category = get_request_var(data, 'config_category')
        if not config_category:
            return jsonify({'message': 'config_category is required'}), 400
        config_category = config_category.lower()

        # 요청에서 namespace 값을 가져오고, 없으면 환경 변수에서 가져옴
        namespace = get_request_var(data, 'namespace', get_env_var('NAMESPACE', 'default'))

        # 요청에서 services 값을 가져옴
        services = get_request_var(data, 'services')
        if services:
            services = [service.strip() for service in services.split(',')]
            yaml_files = [f'/config/{config_category}/{service}.yaml' for service in services]
            # 파일 존재 여부 확인
            missing_files = [yaml_file for yaml_file in yaml_files if not os.path.exists(yaml_file)]
            if missing_files:
                return jsonify({'message': 'Some files are missing', 'missing_files': missing_files}), 400
        else:
            # 마운트된 경로의 모든 YAML 파일을 가져옴
            yaml_files = glob.glob(f'/config/{config_category}/*.yaml')

        # delete_yaml_files 함수 호출 - 즉시 삭제
        errors, deleted_files = delete_yaml_files(namespace, yaml_files, 0)

        if errors:
            logging.info(f'Deletion completed with errors: {errors}')
            return jsonify({
                'message': 'Deletion completed with errors',
                'errors': errors,
                'deleted_files_count': len(deleted_files),
                'deleted_files': deleted_files
            }), 207  # 207: Multi-Status
        logging.info(f'Deletion successful: {deleted_files}')
        return jsonify({
            'message': 'Deletion successful',
                'deleted_files_count': len(deleted_files),
                'deleted_files': deleted_files
        }), 200
    except Exception as e:
        logging.error(f'An error occurred during deletion: {str(e)}')
        return jsonify({'message': 'An error occurred', 'error': str(e)}), 500

if __name__ == '__main__':
    # Flask 애플리케이션 실행
    app.run(host='0.0.0.0', port=5000)