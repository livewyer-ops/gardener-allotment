# Allotment

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Lint](https://github.com/livewyer-ops/gardener-allotment/actions/workflows/lint.yaml/badge.svg)](https://github.com/livewyer-ops/gardener-allotment/actions/workflows/lint.yaml)

Deploy a working [Gardener](https://gardener.cloud) landscape from a single config file. Supports **GCP** and **AWS**. Optionally create a shoot cluster automatically. Designed for evaluating Gardener, not for production.

New to Gardener? Start with the guided [Getting Started](docs/getting-started.md)
path. It explains the Gardener concepts used by this repository, the evaluation
flow, validation checks, Dashboard exploration, and cleanup.

## Quickstart

This is the short command path. Use [Getting Started](docs/getting-started.md)
for the full journey and safety context.

Create a dedicated cloud project/account for evaluation -- Allotment can create
disposable credentials with broad permissions. Use `task teardown` and
`task deauth` to clean up when done.

```bash
# One-time local tool setup
aqua install
export PATH="$(aqua root-dir)/bin:$PATH"

# Pick a provider and copy its config example into place:
cp deploy/config-gcp.yaml.example deploy/config.yaml   # GCP  (GKE + Cloud DNS)
cp deploy/config-aws.yaml.example deploy/config.yaml   # AWS  (EKS + Route 53)
vim deploy/config.yaml    # Set provider, projectId, region, zones

task bootstrap-identity  # Optional: create disposable cloud credentials
task build               # Validate and assemble the provider manifest bundle
task install             # Deploy everything (~25 min)
```

When it finishes, the Gardener Dashboard is running with a registered seed — ready to create shoot clusters.

To also create a default shoot cluster automatically, set `createShoot: "true"` in `deploy/config.yaml` before running `task install`. The shoot takes ~15 minutes to provision after the landscape is ready.

```bash
# Access the Dashboard (port-forward + token in one step)
task dashboard    # http://localhost:8443

# Check resource status
task status

# Tear down (removes all cloud resources including shoots)
task teardown
task deauth       # Remove bootstrap identity and local credentials
```

`task install` is idempotent — safe to re-run if interrupted.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and a running Docker daemon
- [aqua](https://aquaproj.github.io/docs/install/) for the pinned project toolchain
- **GCP**: a dedicated project with billing enabled and permission to enable
  APIs, create service accounts/keys, and grant project roles
- **AWS**: a dedicated account/profile with IAM admin access for the evaluation
  bootstrap identity

Install the aqua-managed tools and add them to your shell path:

```bash
aqua install
export PATH="$(aqua root-dir)/bin:$PATH"
```

After that, `task`, `kind`, `kubectl`, `yq`, `jq`, `yamllint`, `shellcheck`,
`kubeconform`, `chainsaw`, `crossplane`, `aws`, `gcloud`, Go, and
`gke-gcloud-auth-plugin` come from `aqua.yaml`. Docker is intentionally the only
external runtime dependency.

## Configuration

Copy a provider-specific example to `deploy/config.yaml` and edit:

```bash
cp deploy/config-gcp.yaml.example deploy/config.yaml   # GCP
cp deploy/config-aws.yaml.example deploy/config.yaml   # AWS
```

The config is a Crossplane `EnvironmentConfig`. The example files are the
canonical, commented templates — copy one and edit the provider, `projectId`
(GCP project ID or AWS 12-digit account ID without dashes), `region`, `zones`,
and `dnsDomain`. [Getting Started](docs/getting-started.md#choose-a-provider)
explains each field, including how to list valid zones for the selected cloud.

`task bootstrap-identity` is an evaluation helper: it creates a disposable cloud
identity and writes local credentials under `private/`. `task install` then calls
`task load-identity` after Crossplane is available to load those credentials into
Kubernetes secrets. If you already have credentials, use `private/gcp-credentials.json`
or `GCP_CREDENTIALS_FILE=/path/key.json` for GCP, and `awsProfile` or
`private/aws-credentials` for AWS. AWS credentials must be long-lived access keys;
temporary session credentials are rejected because Gardener AWS secrets do not
support them in this flow.

## Architecture

```
deploy/config.yaml → Taskfile.yml → kind cluster → Crossplane
  └─ XAllotment (root, one XR the user creates)
       ├─ cloud ProviderConfig
       ├─ XInfra         → Runtime cluster (EKS/GKE) + VPC + DNS
       ├─ XWorkload      → Gardener operator + cert-manager + runtime bridge
       ├─ XGarden        → Garden CR + DNS Secret + Extension CRs (provider + Calico + OS + cert + DNS)
       ├─ XSeed          → Gardenlet + Seed CR delete-hook
       └─ XVirtualGarden → CloudProfile + Project + credentials + optional shoot
```

One root composite (`XAllotment`) composes five child XRs plus the cloud ProviderConfig. Install: `kubectl apply` one claim, wait on one condition — children converge in parallel. Teardown: `kubectl delete xallotment/garden --cascade=foreground` — composed ClusterUsages release the children in reverse lifecycle order. See [docs/explanation/convergence-model.md](docs/explanation/convergence-model.md) for details.

For a reviewer-focused path through the Kubernetes-native behavior, see
[docs/how-to/capability-demo.md](docs/how-to/capability-demo.md).

For the complete documentation map, see [docs/README.md](docs/README.md).

```
bootstrap/             # Crossplane install + providers
platform/
  definitions.yaml     # 6 XRDs (XAllotment + 5 children)
  functions.yaml       # Composition functions
  configs/             # Version pins
  compositions/
    aws/               # AWS: allotment, infra, workload, garden, seed, virtual
    gcp/               # GCP: allotment, infra, workload, garden, seed, virtual
deploy/
  config.yaml          # EnvironmentConfig (your settings)
  claims/
    aws/allotment.yaml # Single XAllotment claim
    gcp/allotment.yaml # Single XAllotment claim
tests/chainsaw/        # Post-install Kubernetes assertions
```

## Task Targets

`task help` is the authoritative list — it prints every target with descriptions
and the current provider. The lifecycle groups into:

- **Set up & validate** — `bootstrap-identity`, `build`, `validate`, `validate-render`
- **Run** — `install`, `status`, `validate-live`, `observability`
- **Access** — `kubeconfig`, `dashboard`, `token`
- **Tear down** — `teardown`, `deauth`, `verify-clean`, `clean-private`

See [Getting Started](docs/getting-started.md) for the guided flow and
[docs/how-to/troubleshoot-and-recover.md](docs/how-to/troubleshoot-and-recover.md) for recovery.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Hangs at "Infrastructure provisioning..." | Runtime cluster (GKE/EKS) creation (~10 min) | Wait 15 min, then `task status` |
| Hangs at "Garden: Processing" | Gardener deploying (~10 min) | Wait. "Garden: Error" is transient |
| Hangs at "remaining..." | Runtime cluster (GKE/EKS) deletion (~5 min) | Wait |
| GKE cluster stays failed or unavailable | Zone capacity, quota, or cloud API error | `task status`; choose another zone if GCP reports capacity exhaustion |
| `task bootstrap-identity` fails (GCP) | Missing project IAM/API/service-account permissions | Use a dedicated eval project and grant the bootstrap operator the permissions in `docs/reference/permissions.md` |
| `task bootstrap-identity` fails (AWS) | Missing IAM admin on the profile | Use a dedicated eval account and grant the bootstrap operator the permissions in `docs/reference/permissions.md` |
| Dashboard login fails | Garden not ready | `task status`, wait for Succeeded |
| Shoot stuck at "Processing" | Worker nodes bootstrapping (~5 min) | Wait. Check Dashboard for progress |

For expected-but-alarming install/teardown signals (gardenlet crashloop during
seed drain, transient `SeedAuthorizer` denials, the AWS pod-CIDR gate) and
recovery steps, see [docs/how-to/troubleshoot-and-recover.md](docs/how-to/troubleshoot-and-recover.md).

## Limitations and Security

This is an **evaluation sandbox**, not production infrastructure:

- **GCP** and **AWS** supported; single region with provider-specific runtime
  zone counts (GCP one or more, AWS two to four)
- Cloud cost varies by provider and zone count; AWS creates one NAT gateway per
  configured runtime zone, and shoots add their own resources
- Private DNS only (no domain ownership needed)
- Shoots share the seed VPC for private DNS resolution (GCP via Cloud Router, AWS via secondary CIDR)
- Staging TLS certificates (browser warnings)
- Resource-level admin cloud credentials in a dedicated eval account/project, non-expiring tokens, broad Kubernetes service accounts, no authorized networks
- Always run `task teardown` when finished

See [docs/reference/permissions.md](docs/reference/permissions.md) for the current permission and
public API endpoint posture.

This is an evaluation sandbox; for production Gardener, follow the official
[Gardener documentation](https://gardener.cloud/docs/).

## What's Next

- Explore the shoot cluster via the [Gardener Dashboard](https://gardener.cloud/docs/dashboard/)
- Read the [Gardener documentation](https://gardener.cloud/docs/)

## Getting Help

Use GitHub issues for bug reports and feature requests. For vulnerabilities, see
[SECURITY.md](SECURITY.md) and report privately. For support boundaries, see
[SUPPORT.md](SUPPORT.md).

## License

Apache License 2.0 — see [LICENSE](LICENSE)
