# Getting started

This guide is for someone evaluating Gardener for the first time. It explains
what Allotment builds, how to run it safely, what to inspect, and how to remove
everything afterwards.

## What you will build

Allotment creates a disposable Gardener landscape in your own AWS account or GCP
project:

- A local kind cluster that runs Crossplane.
- A cloud runtime cluster: EKS on AWS or GKE on GCP.
- Gardener installed into that runtime cluster.
- A registered seed, so Gardener can create shoot clusters.
- Optional default shoot cluster named `eval`.
- A Dashboard login path for exploring the result.

The goal is evaluation. The defaults favor a repeatable demo over production
hardening.

## Gardener concepts in this repository

| Concept | How to think about it here |
|---|---|
| [Garden](https://gardener.cloud/docs/gardener/concepts/operator/) | The Gardener control plane installed on the runtime cluster |
| [Seed](https://gardener.cloud/docs/getting-started/architecture/) | The runtime cluster registered as capacity for shoot clusters |
| [Shoot](https://gardener.cloud/docs/getting-started/architecture/) | A Kubernetes cluster created by Gardener for a user workload |
| [CloudProfile](https://gardener.cloud/docs/gardener/api-reference/core/) | The provider and machine/version choices Gardener exposes |
| [Project](https://gardener.cloud/docs/gardener/api-reference/core/) | The Gardener tenant namespace where the optional shoot is created |
| [Dashboard](https://gardener.cloud/docs/dashboard/) | The web UI used to inspect the Garden, seed, project, and shoots |

For the full product model, use the official
[Gardener documentation](https://gardener.cloud/docs/) and its
[architecture overview](https://gardener.cloud/docs/getting-started/architecture/).
This guide only covers the path Allotment automates.

## Before you start

Use a dedicated cloud account or project. Allotment can create broad evaluation
credentials and real billable resources.

Install the local prerequisites:

- Docker, or Podman with its API socket enabled (see the Podman note below)
- [aqua](https://aquaproj.github.io/docs/install/)

Then clone the repository, install aqua-managed tools, and add aqua's bin
directory to your shell path:

```bash
aqua install
export PATH="$(aqua root-dir)/bin:$PATH"
```

After this step, Allotment's standard commands use the pinned `task`, `kind`,
`kubectl`, `aws`, `gcloud`, Go, `yq`, `jq`, validation tools, and Crossplane
CLI from `aqua.yaml`. The container runtime remains external because it is a
local runtime, not just a CLI.

**Using Podman instead of Docker.** The tasks detect Podman automatically and
talk to it through its Docker-compatible API - no `docker` symlink or alias is
needed. Enable the API socket first (Linux:
`systemctl --user start podman.socket`; macOS: `podman machine start`), and on
macOS give the Podman machine at least 8 GiB of memory
(`podman machine set --memory 8192`) - the 2 GiB default fails much later with
misleading provider-health timeouts. If Docker and Podman are both installed,
set `KIND_EXPERIMENTAL_PROVIDER=podman` to make kind use Podman.

## Choose a provider

For GCP:

```bash
cp deploy/config-gcp.yaml.example deploy/config.yaml
```

For AWS:

```bash
cp deploy/config-aws.yaml.example deploy/config.yaml
```

Edit `deploy/config.yaml`. The most important fields are:

- `provider`: `gcp` or `aws`
- `projectId`: GCP project ID or AWS 12-digit account ID, without dashes
- `region`: cloud region
- `zones`: runtime zones in that region; GCP accepts one or more, AWS accepts
  two to four
- `dnsDomain`: private evaluation domain
- `createShoot`: `"false"` for only the landscape, `"true"` to also create a
  default shoot

List zones before editing the file:

```bash
gcloud compute zones list --filter='region:europe-west1' --format='value(name)'
aws ec2 describe-availability-zones --region eu-west-1 \
  --query 'AvailabilityZones[].ZoneName' --output text
```

GCP zone names are regional, but a valid zone can still be temporarily short on
capacity. AWS zone names are account-mapped, so use the names returned for the
account that will run the evaluation.

GCP also needs `vpcNetwork`. AWS also needs `awsProfile` and a Garden Linux AMI
for the selected region. Garden Linux is the operating system name.

## Plan the cloud footprint

The defaults create real resources:

- GCP creates a regional GKE runtime cluster with `gcpNodesPerZone × len(zones)`
  `e2-standard-8` nodes. The example config (2 nodes/zone × 2 zones, 100 GB
  disk each) needs 32 vCPUs and 400 GB of standard persistent disk in the
  region - sized to fit a fresh project's default quotas.
- AWS creates an EKS runtime cluster with `awsNodesPerZone × len(zones)`
  `m5.xlarge` nodes, plus one NAT gateway per configured runtime zone.
- Setting `createShoot: "true"` adds a Gardener-managed shoot cluster after the
  landscape is ready.

Check the footprint against your project's actual quotas before installing:

```bash
task preflight
```

It computes the vCPU and disk requirements from `deploy/config.yaml`, compares
them with the region's real quota headroom, and tells you exactly what to
request if the project falls short. Raising `gcpNodesPerZone` or the zone
count raises the requirement accordingly.

Use a dedicated account or project, and tear it down when the evaluation is
finished.

## Create or load credentials

For a disposable evaluation identity:

```bash
task bootstrap-identity
```

This writes credentials under `private/`, which is gitignored.

If you already have suitable credentials:

- GCP: put a service-account key at `private/gcp-credentials.json`, or run with
  `GCP_CREDENTIALS_FILE=/path/to/key.json task install`.
- AWS: set `awsProfile` in `deploy/config.yaml`, or put a standard credentials
  file at `private/aws-credentials`.

AWS credentials must be long-lived access keys. Temporary session credentials
from AWS SSO or STS are rejected because Gardener AWS secrets currently need
non-expiring access key material.

Review [Permissions](reference/permissions.md) before using a shared account.

## Build and validate locally

Run the static checks before creating cloud resources:

```bash
task validate
task validate-render
task build
```

These commands validate YAML and Taskfiles, render the Crossplane compositions
for both providers, and assemble the provider-specific bundle.

## Install the landscape

```bash
task install
```

The install creates the local kind management cluster, installs Crossplane,
loads credentials, provisions the cloud runtime cluster, installs Gardener, and
runs Chainsaw post-install validation.

Typical timing:

- Landscape only: around 25 minutes
- With `createShoot: "true"`: around 40 minutes

You can rerun `task install` if the process is interrupted.

## Validate the result

`task install` runs `task validate-live` once the landscape is ready. To re-check
the result later:

```bash
task status
task validate-live
task observability
```

You should see:

- `XAllotment` and child XRs ready.
- Crossplane providers healthy.
- Runtime Garden conditions healthy.
- No stuck pending pods in the Gardener namespace.
- If `createShoot: "true"`, the default shoot object ready.

## Explore Gardener

Start the Dashboard port-forward:

```bash
task dashboard
```

Open `http://localhost:8443` and use the printed token.

For a first evaluation, inspect:

- The registered seed.
- The project created by Allotment.
- The CloudProfile for your provider.
- The optional `eval` shoot, if enabled.
- Events and health conditions during creation.

## Clean up

Always remove cloud resources when you finish:

```bash
task teardown
task deauth
task verify-clean
```

`task teardown` deletes the root `XAllotment`; Crossplane and Gardener reconcile
the cleanup through the dependency chain. `task deauth` removes the disposable
cloud identity and local credentials. `task verify-clean` performs a read-only
cloud leftover audit for deterministic Allotment resource names.

## What to read next

- [Capability demo](how-to/capability-demo.md) for a reviewer-focused tour.
- [Convergence model](explanation/convergence-model.md) and [teardown ordering](explanation/teardown-ordering.md) for the design.
- [Permissions](reference/permissions.md) for credential posture.
