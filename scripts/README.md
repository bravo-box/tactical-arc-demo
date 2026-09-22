# scripts

General scripts for the repository.

- `lint.sh` – run shellcheck, `terraform fmt -check`, and `helm lint`.
- `build-images.sh` – shared image build helper used by the per-section build scripts.
- `verify-tools.sh` – verify the dev container tooling (git/ssh, kubectl, helm, az, terraform, packer).
