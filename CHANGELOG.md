# Changelog

All notable changes to this project are documented here. This project follows
[Conventional Commits](https://www.conventionalcommits.org/) and
[Semantic Versioning](https://semver.org/).

## 1.1.0 — 2026-06-18

Zone-count flexibility for runtime clusters.

- Added provider-aware runtime zone validation: GCP accepts one or more zones,
  AWS accepts two to four zones.
- Changed GCP infrastructure rendering to pass the full configured zone list to
  GKE `nodeLocations`.
- Refactored AWS zone-shaped infrastructure to render from a four-slot table:
  public, private, and pod subnets; per-zone NAT gateways; per-zone private route
  tables; route associations; ENIConfigs; pod-CIDR probes; and node group sizing.
- Added `awsNodesPerZone` for AWS runtime node sizing.
- Extended render validation to exercise three-zone AWS and GCP configurations.

## 1.0.0 — 2026-06-16

Initial public release.

- Deploy a working [Gardener](https://gardener.cloud) evaluation landscape on
  **GCP** (GKE + Cloud DNS) or **AWS** (EKS + Route 53) from a single config file.
- One root `XAllotment` Crossplane composite over five child XRs: install with a
  single `kubectl apply`, tear down with a single foreground `kubectl delete`
  whose order is enforced by composed `ClusterUsage` resources.
