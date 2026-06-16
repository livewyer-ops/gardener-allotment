# Getting Started

This guide is for someone evaluating Gardener for the first time. It explains
what Allotment builds, how to run it safely, what to inspect, and how to remove
everything afterwards.

## What You Will Build

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

## Gardener Concepts In This Repository

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

## Before You Start

Use a dedicated cloud account or project. Allotment can create broad evaluation
credentials and real billable resources.

Install the local prerequisites:

- Docker
- aqua

Then clone the repository, install aqua-managed tools, and add aqua's bin
directory to your shell path:

```bash
aqua install
export PATH="$(aqua root-dir)/bin:$PATH"
```

After this step, Allotment's standard commands use the pinned `task`, `kind`,
`kubectl`, `aws`, `gcloud`, Go, `yq`, `jq`, validation tools, and Crossplane
CLI from `aqua.yaml`. Docker remains external because it is a local runtime, not
just a CLI.

## Choose A Provider

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
- `projectId`: GCP project ID or AWS account ID
- `region`: cloud region
- `zones`: exactly two runtime zones in that region
- `dnsDomain`: private evaluation domain
- `createShoot`: `"false"` for only the landscape, `"true"` to also create a
  default shoot

GCP also needs `vpcNetwork`. AWS also needs `awsProfile` and a Garden Linux AMI
for the selected region.

## Create Or Load Credentials

For a disposable evaluation identity:

```bash
task bootstrap-identity
```

This writes credentials under `private/`, which is gitignored. If you already
have suitable credentials, place them under `private/` or set the documented
environment variable for your provider, then let `task install` load them into
Crossplane.

Review [Permissions](reference/permissions.md) before using a shared account.

## Build And Validate Locally

Run the static checks before creating cloud resources:

```bash
task validate
task validate-render
task build
```

These commands validate YAML and Taskfiles, render the Crossplane compositions
for both providers, and assemble the provider-specific bundle.

## Install The Landscape

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

## Validate The Result

After install:

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

## Clean Up

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

## What To Read Next

- [Capability Demo](how-to/capability-demo.md) for a reviewer-focused tour.
- [Convergence model](explanation/convergence-model.md) and [teardown ordering](explanation/teardown-ordering.md) for the design.
- [Permissions](reference/permissions.md) for credential posture.
