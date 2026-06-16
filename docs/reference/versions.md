# Version reference

Every control-plane, provider, function, Gardener, extension, and Kubernetes
version is pinned. To avoid drift, the docs do not duplicate the version
numbers — the authoritative sources are the files below.

## Sources of truth

| Area | File |
|---|---|
| Gardener core, extensions, cert-manager, virtual-garden/shoot Kubernetes | `platform/configs/versions-shared.yaml` |
| GCP provider + GKE runtime + on-runtime Crossplane/provider-kubernetes | `platform/configs/versions-gcp.yaml` |
| AWS provider + EKS runtime + on-runtime Crossplane/provider-kubernetes | `platform/configs/versions-aws.yaml` |
| Crossplane + bootstrap providers (helm, kubernetes, aws, gcp) | `bootstrap/crossplane.yaml`, `bootstrap/providers-*.yaml` |
| Composition functions | `platform/functions.yaml` |
| Local toolchain (except Docker) | `aqua.yaml` |

Compositions read the EnvironmentConfig versions at runtime rather than
hard-coding them. The versions validated for a given release are recorded in
[CHANGELOG.md](../../CHANGELOG.md).

## Composition functions

Which function each composition pipeline uses (versions pinned in
`platform/functions.yaml`):

| Function | Used by |
|---|---|
| function-patch-and-transform | Infra, Workload |
| function-go-templating | Allotment, Workload, Garden, Seed, Virtual |
| function-extra-resources | Workload, Virtual |
| function-sequencer | Infra, Workload, Virtual |
| function-auto-ready | All compositions |
| function-environment-configs | All compositions |
