# Documentation

Allotment is written for people **evaluating** Gardener, not for people who
already operate a production landscape. The docs follow the
[Diátaxis](https://diataxis.fr/) model — four kinds of documentation for four
different needs:

| Kind | When you want to… | Where |
|---|---|---|
| **Tutorial** | learn by doing, end to end | [getting-started.md](getting-started.md) |
| **How-to guides** | accomplish a specific task | [how-to/](how-to/) |
| **Reference** | look up precise facts | [reference/](reference/) |
| **Explanation** | understand *why* it works this way | [explanation/](explanation/) |

## Start here

New to Gardener and to Allotment? Read **[getting-started.md](getting-started.md)**
— it builds the mental model, installs a landscape, validates it, tours the
Dashboard, and tears everything down.

## How-to guides

- [capability-demo.md](how-to/capability-demo.md) — reviewer-focused tour of the Kubernetes/cloud-native behaviour
- [troubleshoot-and-recover.md](how-to/troubleshoot-and-recover.md) — expected install/teardown signals, diagnosis, recovery
- [add-a-provider.md](how-to/add-a-provider.md) — port Allotment to another cloud

## Reference

- [config.md](reference/config.md) — `deploy/config.yaml` schema
- [task-targets.md](reference/task-targets.md) — task commands and provider dispatch
- [resources.md](reference/resources.md) — directory layout, XRDs, per-composition resources
- [versions.md](reference/versions.md) — version sources of truth, composition functions
- [permissions.md](reference/permissions.md) — credential model and endpoint posture

## Explanation

- [convergence-model.md](explanation/convergence-model.md) — how one apply converges the whole landscape
- [teardown-ordering.md](explanation/teardown-ordering.md) — how one delete tears it down in order
- [networking.md](explanation/networking.md) — seed/shoot CIDR design on each provider
- [double-nesting.md](explanation/double-nesting.md) — reaching the virtual garden API

## What this project does not document

This repository does not replace the official Gardener documentation. It explains
how Allotment assembles a small evaluation landscape and points to
[Gardener](https://gardener.cloud/docs/) for the broader product concepts, APIs,
and production guidance.
