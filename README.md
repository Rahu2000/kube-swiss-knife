# kube-swiss-knifes

KubeTools: A collection of Kubernetes management tools like a Swiss Army knife.

- kube-maintainer: Manages plugin deployment and removal in Kubernetes clusters with a Flask application.
- disk-sweeper: Cleans up disk space on Kubernetes nodes by removing unnecessary files and data.
- multiarch-image-to-ecr: A tool for managing public image registry images in a private ECR.
- helm-charts-to-ecr: Automates the migration of Helm Charts from public repositories to a private Amazon ECR, enabling secure and efficient chart management.
- docker-monitoring: Registers a service based on node-exporter and cAdvisor to monitor Docker via systemd, enabling automatic management, restart, log integration, and boot-time execution for enhanced operational stability.
- ghe-helm-charts: Automates Helm chart repository management and publishing for air-gapped or enterprise environments. Provides chart packaging, index generation, and GitHub Pages integration for easy distribution.
