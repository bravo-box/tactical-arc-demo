# tactical-arc-demo

Build out an application showing remote management of a device at the edge using Arc, and connecting to a the cloud for data and telemetry.

## Repository layout

| Path | Purpose |
| --- | --- |
| `/infra` | Terraform templates for Azure Government, authenticated with the logged-in Azure CLI user. |
| `/cloud-cluster` | The apps to run the cloud cluster. |
| `/cloud-cluster/apps` | Containerized app source code and Dockerfiles. |
| `/cloud-cluster/helm` | Helm chart deploying the cloud apps and dependencies onto the cluster. |
| `/cloud-cluster/scripts` | Scripts for building and deploying the cloud section. |
| `/remote-cluster` | The apps designed to run at the edge. |
| `/remote-cluster/apps` | Containerized edge app source code and Dockerfiles. |
| `/remote-cluster/helm` | Helm chart for deploying the apps to the edge device. |
| `/remote-cluster/scripts` | Edge scripts, including Kubernetes/Docker stand-up for the edge cluster. |
| `/scripts` | General scripts for the repo. |

## Dev container

`.devcontainer/` provides a container with everything needed to work on this repo:

- **SSH git authentication** – the host `~/.ssh` directory is mounted (read-only) and copied
  into the container with correct permissions, GitHub host keys are trusted, and available
  keys are added to the SSH agent. VS Code also forwards the host `ssh-agent`.
- **kubectl** and **helm**
- **Azure CLI** (defaults to the `AzureUSGovernment` cloud via `AZURE_CLOUD`)
- **Terraform** (with tflint)
- **Packer** (installed from the HashiCorp apt repository in `post-create.sh`)
- Docker-in-Docker for building the container images

Verify the tooling inside the container with:

```bash
./scripts/verify-tools.sh
```

## Linting

```bash
./scripts/lint.sh
```
