# Changelog

All notable changes to this project are documented here. This project follows
[Conventional Commits](https://www.conventionalcommits.org/) and
[Semantic Versioning](https://semver.org/).

## 1.0.0 — 2026-06-16

Initial public release.

- Deploy a working [Gardener](https://gardener.cloud) evaluation landscape on
  **GCP** (GKE + Cloud DNS) or **AWS** (EKS + Route 53) from a single config file.
- One root `XAllotment` Crossplane composite over five child XRs: install with a
  single `kubectl apply`, tear down with a single foreground `kubectl delete`
  whose order is enforced by composed `ClusterUsage` resources.
