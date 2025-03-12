import unittest
from unittest.mock import patch, MagicMock
from app import app, delete_yaml_files

class TrafficMaintainerTestCase(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True
        print(f"\nStarting test: {self._testMethodName}")

    def tearDown(self):
        print(f"Finished test: {self._testMethodName}")

    def test_health_check(self):
        print("Testing health check endpoint")
        response = self.app.get('/healthz', headers={'Content-Type': 'application/json'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, {'status': 'healthy'})

    @patch('app.os.getenv')
    @patch('app.glob.glob')
    @patch('app.subprocess.run')
    def test_deploy(self, mock_subprocess_run, mock_glob, mock_getenv):
        print("Testing deploy endpoint")
        mock_getenv.side_effect = lambda key, default=None: 'default' if key == 'NAMESPACE' else '3' if key == 'SLEEP_TIME' else default
        mock_glob.return_value = ['/config/envoyfilter/test.yaml']
        mock_subprocess_run.return_value = MagicMock(returncode=0)

        response = self.app.post('/maintainer/plugin/deploy', json={
            'config_category': 'envoyfilter',
            'namespace': 'default',
            'auto_delete': 'false'
        }, headers={'Content-Type': 'application/json'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json['message'], 'Deployment successful')

    @patch('app.os.getenv')
    @patch('app.glob.glob')
    @patch('app.subprocess.run')
    def test_deploy_with_errors(self, mock_subprocess_run, mock_glob, mock_getenv):
        print("Testing deploy endpoint with errors")
        mock_getenv.side_effect = lambda key, default=None: 'default' if key == 'NAMESPACE' else '3' if key == 'SLEEP_TIME' else default
        mock_glob.return_value = ['/config/envoyfilter/test.yaml']
        mock_subprocess_run.return_value = MagicMock(returncode=1, stderr='Error')

        response = self.app.post('/maintainer/plugin/deploy', json={
            'config_category': 'envoyfilter',
            'namespace': 'default',
            'auto_delete': 'false'
        }, headers={'Content-Type': 'application/json'})
        self.assertEqual(response.status_code, 207)
        self.assertIn('errors', response.json)

    @patch('app.os.getenv')
    @patch('app.glob.glob')
    @patch('app.subprocess.run')
    def test_delete(self, mock_subprocess_run, mock_glob, mock_getenv):
        print("Testing delete endpoint")
        mock_getenv.side_effect = lambda key, default=None: 'default' if key == 'NAMESPACE' else default
        mock_glob.return_value = ['/config/envoyfilter/test.yaml']
        mock_subprocess_run.return_value = MagicMock(returncode=0)

        response = self.app.post('/maintainer/plugin/delete', json={
            'config_category': 'envoyfilter',
            'namespace': 'default'
        }, headers={'Content-Type': 'application/json'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json['message'], 'Deletion successful')

    @patch('app.os.getenv')
    @patch('app.glob.glob')
    @patch('app.subprocess.run')
    def test_delete_with_errors(self, mock_subprocess_run, mock_glob, mock_getenv):
        print("Testing delete endpoint with errors")
        mock_getenv.side_effect = lambda key, default=None: 'default' if key == 'NAMESPACE' else default
        mock_glob.return_value = ['/config/envoyfilter/test.yaml']
        mock_subprocess_run.return_value = MagicMock(returncode=1, stderr='Error')

        response = self.app.post('/maintainer/plugin/delete', json={
            'config_category': 'envoyfilter',
            'namespace': 'default'
        }, headers={'Content-Type': 'application/json'})
        self.assertEqual(response.status_code, 207)
        self.assertIn('errors', response.json)

    @patch('app.time.sleep', return_value=None)
    @patch('app.subprocess.run')
    def test_delete_yaml_files(self, mock_subprocess_run, mock_sleep):
        print("Testing delete_yaml_files function")
        mock_subprocess_run.return_value = MagicMock(returncode=0)
        errors, deleted_files = delete_yaml_files('default', ['/config/envoyfilter/test.yaml'], 0)
        self.assertEqual(errors, [])

    @patch('app.time.sleep', return_value=None)
    @patch('app.subprocess.run')
    def test_delete_yaml_files_with_errors(self, mock_subprocess_run, mock_sleep):
        print("Testing delete_yaml_files function with errors")
        mock_subprocess_run.return_value = MagicMock(returncode=1, stderr='Error')
        errors, deleted_files = delete_yaml_files('default', ['/config/envoyfilter/test.yaml'], 0)
        self.assertEqual(len(errors), 1)
        self.assertEqual(errors[0]['error'], 'Error')

if __name__ == '__main__':
    unittest.main()