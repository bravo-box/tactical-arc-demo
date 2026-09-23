# remote-cluster/scripts

Scripts intended to run on the edge device.

- `install-kubernetes.sh` – install and configure Docker and a single-node K3s cluster.
- `connect-arc.sh` – discover Azure context/resource groups and onboard the cluster to Arc.
- `configure-service-bus.sh` – create the heartbeat topic/subscription and a sender-only device credential.
- `build-images.sh` – build and optionally push the edge app images.
- `deploy.sh` – securely install/upgrade a local or remote edge Helm chart.
