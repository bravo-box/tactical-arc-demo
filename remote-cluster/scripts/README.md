# remote-cluster/scripts

Scripts intended to run on the edge device.

- `install-kubernetes.sh` – install and configure Docker and a single-node K3s cluster.
- `configure-vpn.sh` – bring up an IKEv2 site-to-site tunnel (strongSwan) to the Azure VPN Gateway and pin private endpoint names in `/etc/hosts`.
- `configure-registry.sh` – create/configure ACR for anonymous pull or grant the signed-in Azure CLI identity `AcrPull` (run on a workstation).
- `replicate-images.sh` – pre-pull edge images using the device's Azure CLI sign-in and optionally configure K3s registry auth.
- `connect-arc.sh` – discover Azure context/resource groups and onboard the cluster to Arc.
- `configure-service-bus.sh` – create heartbeat and location messaging entities with least-privilege edge credentials.
- `build-images.sh` – build and optionally push the edge app images.
- `deploy.sh` – securely install/upgrade a local or remote edge Helm chart.
