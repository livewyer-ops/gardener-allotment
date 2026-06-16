# Capability Demo

This path is for reviewers who have completed
[Getting Started](../getting-started.md) and want to see the cloud-native and
Kubernetes capabilities directly rather than only reading the architecture.

## Demo Flow

1. Configure a provider:

   ```bash
   cp deploy/config-gcp.yaml.example deploy/config.yaml   # GCP
   cp deploy/config-aws.yaml.example deploy/config.yaml   # AWS
   ```

2. Edit `deploy/config.yaml`, then create evaluation credentials if needed:

   ```bash
   task bootstrap-identity
   ```

3. Build and validate the provider bundle:

   ```bash
   task build
   task validate-render
   ```

4. Install the platform:

   ```bash
   task install
   ```

5. Inspect convergence from the Kubernetes API:

   ```bash
   task validate-live
   task observability
   task status
   kubectl get xallotment,xinfra,xworkload,xgarden,xseed,xvirtualgarden
   kubectl get managed -o wide
   ```

6. Open Gardener:

   ```bash
   task kubeconfig
   task dashboard
   ```

7. Optional: set `createShoot: "true"` in `deploy/config.yaml`, rerun
   `task install`, and inspect the `eval` shoot in the Dashboard.

8. Clean up:

   ```bash
   task teardown
   task deauth
   task verify-clean
   ```

## Capability Map

| Capability | Implementation | User-visible outcome |
|---|---|---|
| One Kubernetes-facing product API | `XAllotment` in `platform/definitions.yaml` and `deploy/claims/<provider>/allotment.yaml` | Users apply or delete one root resource while the platform composes the rest |
| Cloud abstraction through Crossplane | Provider-specific compositions under `platform/compositions/aws/` and `platform/compositions/gcp/` | The same workflow provisions EKS/Route 53 or GKE/Cloud DNS |
| Declarative configuration | `deploy/config.yaml` as an `EnvironmentConfig` | Provider, project, region, DNS domain, and shoot toggle flow into every composition |
| Composition functions | `function-environment-configs`, `function-go-templating`, `function-sequencer`, `function-auto-ready` in `platform/functions.yaml` | Shared templates stay provider-aware without sed-style manifest mutation |
| Multi-cluster control | Helm and Kubernetes ProviderConfigs created by `XInfra` and `XWorkload` | The kind control plane installs into the runtime cluster and virtual garden API |
| Gardener lifecycle automation | `XGarden`, `XSeed`, and `XVirtualGarden` compositions | Gardener operator, gardenlet, CloudProfile, Project, credentials, and optional shoot converge together |
| Ordered teardown | `ClusterUsage` resources composed by the root and child XRs | Foreground deletion releases virtual, seed, garden, workload, infra, and ProviderConfig in the right order |
| Render validation | `tests/render/expected/` and `task validate-render` | Shared templates are rendered through Crossplane CLI for both providers before any cloud resources are created |
| Post-install validation | `tests/chainsaw/post-install/` and `task validate-live` | Reviewers get declarative assertions for Crossplane provider health, root/child XR readiness, and runtime Garden health |
| Runtime observability | `task observability` | Reviewers can inspect runtime readiness, API metrics, Garden pods, and warning events without relying on metrics-server |
| Operational interface | `Taskfile.yml`, `.tasks/`, and `aqua.yaml` | Users get pinned tools, preflight checks, build/validation artifacts, status, dashboard access, and cleanup from one command surface |
