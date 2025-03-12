# disk-sweeper

A tool to clean up disk space on Kubernetes nodes using nerdctl or crictl.

`disk-sweeper` is a project designed to clean up disk space on Kubernetes nodes. This tool helps to free up disk space by removing unnecessary files and data, optimizing system performance. `disk-sweeper` runs automatically in a Kubernetes environment and performs disk cleanup tasks based on configured rules.

## kubernetes 배포

[CronJob 배포 예제](../examples/diks-sweeper/disk-sweeper.yaml)
