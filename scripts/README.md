# scripts

General scripts for the repository.

- `lint.sh` – run shellcheck, `terraform fmt -check`, and `helm lint`.
- `build-images.sh` – shared image build helper used by the per-section build scripts.
- `verify-tools.sh` – verify the dev container tooling (git/ssh, kubectl, helm, az, terraform, packer).
- `download-airgap.sh` – download an OCI Helm chart and an explicit image list into a portable offline bundle.
- `upload-airgap.sh` – verify a bundle and publish its chart and images to a destination registry.

## Air-gap registry transfer

Run the download on a connected machine, copy the **entire bundle directory**
onto removable media, then run the upload on a machine inside the air gap that
can reach the destination registry. No Docker daemon is needed. Both machines
need Bash, Python 3, Helm 3 with OCI support, and `skopeo` on `PATH`.
Install these using your OS package manager; Skopeo is not currently included
in the dev container. The destination must support OCI images and Helm charts.
Multi-architecture images are copied with all available architectures, so the
transfer machine need not match the edge device's CPU.

Authenticate outside the scripts, separately for Helm and Skopeo:

```bash
helm registry login source.example.com
skopeo login source.example.com
# On the destination machine:
helm registry login registry.example.internal
skopeo login registry.example.internal
```

Use the hostname only when logging in, even if artifacts use a repository
prefix. Use your registry's credentials (including an ACR token where
appropriate), supplied interactively or via the tools' password-stdin support.
Credentials are not stored in bundles. TLS verification remains enabled;
configure trusted certificates for private registries rather than disabling it.

### Download

The chart must already be published to an OCI registry. Choose its exact
version and list **every image required by your deployment**, including
init containers, Helm hooks, sidecars, dependency charts, and enabled optional
components. The scripts deliberately do not infer images from Helm values or
copy deployment secrets. Check `helm template` with your actual values against
your image list before exporting; no upstream pulls should remain after
deployment. Image tags are independent of the Helm chart's version/appVersion.

For the remote chart at version `0.3.1`, this example includes the default
workloads and optional camera pipeline. Replace the source registry and tags
with your published images:

```bash
mkdir -p airgap-bundles
cat >airgap-bundles/edge-images.txt <<'EOF'
source.example.com/edge-heartbeat:0.1.0
source.example.com/device-service:0.1.0
source.example.com/location-service:0.1.0
docker.io/library/eclipse-mosquitto:2.0.22=eclipse-mosquitto:2.0.22
docker.io/library/busybox:1.36=busybox:1.36
# These two are only needed with imagePipeline.enabled=true:
source.example.com/camera-capture:0.1.0
source.example.com/image-uploader:0.1.0
EOF

./scripts/download-airgap.sh \
  --chart oci://source.example.com/charts/remote-cluster \
  --chart-version 0.3.1 \
  --images-file airgap-bundles/edge-images.txt \
  --bundle airgap-bundles/edge-0.3.1
```

Alternatively, repeat `--image SOURCE[=DESTINATION_REPOSITORY:TAG]`.
By default the source registry is removed and repository paths/tags are
retained. An explicit destination alias, as above for Docker Hub's `library`
images, ensures the destination matches the chart's image repositories.
Digest-pinned sources require a destination repository/tag alias. Blank lines
and full-line `#` comments are allowed in image lists.
Docker-format manifests may be converted to OCI format during download.
All platforms are retained, but upstream manifest digests/signatures are not
guaranteed to survive that conversion; destination tags refer to the bundled
OCI content.

For the cloud chart, use
`--chart oci://source.example.com/charts/cloud-cluster --chart-version 0.2.0`
and an image list containing `source.example.com/telemetry-api:0.1.0`.
Repeat the workflow for each chart. Override destinations when your sources
have prefixes that should not appear in the destination chart values.

The bundle contains the downloaded chart, OCI image layouts, and a manifest
with SHA-256 checksums. Existing output directories are not overwritten; failed
downloads are cleaned up rather than presented as complete bundles. Bundles
and local image lists under `airgap-bundles/` are ignored by Git.
Checksums detect corruption, not malicious replacement of both artifacts and
the manifest: transfer bundles through a trusted channel.

### Upload and deploy

After copying the bundle into the air gap:

```bash
./scripts/upload-airgap.sh \
  --bundle airgap-bundles/edge-0.3.1 \
  --registry registry.example.internal/tactical
```

The uploader validates the bundle before publishing anything. Images go to
`registry.example.internal/tactical/<destination-repository>:<tag>`; the chart
goes to `oci://registry.example.internal/tactical/charts/<chart-name>`.
An upload is not transactional across registry artifacts: if it fails partway
through, fix the connectivity/permissions issue and rerun the same bundle.
Upload reads images and charts only from the bundle, not the source registry.

Deploy using the destination registry for **all** image repositories:

```bash
helm upgrade --install remote-cluster \
  oci://registry.example.internal/tactical/charts/remote-cluster \
  --version 0.3.1 --namespace tactical-arc --create-namespace \
  --set-string imageRegistry=registry.example.internal/tactical
```

Add your device configuration, secrets, imagePullSecrets, and other deployment
values as usual; the bundle does not contain them. Enable
`imagePipeline.enabled=true` only when its images and required configuration
are included. Chart `0.3.1` also routes the BusyBox location init container
through `imageRegistry`; older remote charts hard-code a public BusyBox image
and must be updated before an air-gapped deployment. The cloud chart uses the
same `imageRegistry` setting. For custom image paths/tags, update the
corresponding chart values to match the uploader's printed destinations.

This transfers application artifacts only. K3s/Kubernetes installation
artifacts and continued Azure Arc/data-service connectivity are separate
requirements; copying images does not make Azure services available offline.

### VS Code tasks

Use **Terminal → Run Task**:

- **Air gap: download chart and images** prompts for the OCI chart, version,
  image-list file, and new output bundle directory.
- **Air gap: upload chart and images** prompts for the copied bundle directory
  and destination registry/prefix.

Authenticate in the terminal first. Paths may be absolute or relative to the
workspace root. The tasks use process arguments rather than shell
interpolation, so spaces and shell metacharacters in inputs are not executed.

Run the transfer scripts' offline unit tests without registry credentials:

```bash
python3 -m unittest discover -s scripts -p test_airgap.py -v
```
