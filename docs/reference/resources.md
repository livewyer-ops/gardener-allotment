# Resource reference

Facts about what each composition creates and how the repository is laid out. For
*why* the design is shaped this way, see [explanation/](../explanation/).

## Directory layout

```
allotment/
  Taskfile.yml                       # Public task interface
  .tasks/                            # Provider-dispatched task groups
  kind.yaml                          # kind cluster config

  deploy/
    config.yaml                      # EnvironmentConfig (user settings)
    config-aws.yaml.example          # AWS config template
    config-gcp.yaml.example          # GCP config template
    claims/
      aws/allotment.yaml             # The single XAllotment claim (provider: aws)
      gcp/allotment.yaml             # The single XAllotment claim (provider: gcp)

  bootstrap/
    crossplane.yaml                  # Crossplane Helm chart (inline)
    providers-common.yaml            # provider-helm, provider-kubernetes, ClusterRoleBinding
    providers-aws.yaml               # AWS Crossplane providers
    providers-gcp.yaml               # GCP Crossplane providers

  platform/
    definitions.yaml                 # 6 XRDs (XAllotment + 5 child XRs)
    functions.yaml                   # Crossplane composition functions (shared)
    configs/                         # versions-shared / versions-aws / versions-gcp
    templates/                       # Go templates for function-go-templating
    compositions/{aws,gcp}/          # allotment, infra, workload, garden, seed, virtual
```

## XRDs

Six XRDs in `platform/definitions.yaml`:

| XRD | Kind | Purpose |
|---|---|---|
| `xallotments.allotment.io` | XAllotment | **Root**: composes cloud ProviderConfig + the five child XRs |
| `xinfras.allotment.io` | XInfra | Runtime cluster (EKS/GKE) + VPC + DNS |
| `xworkloads.allotment.io` | XWorkload | Gardener operator + secrets + cert-manager + runtime bridge |
| `xgardens.allotment.io` | XGarden | Garden CR + DNS Secret + Extension CRs |
| `xseeds.allotment.io` | XSeed | Gardenlet + Seed CR delete-hook |
| `xvirtualgardens.allotment.io` | XVirtualGarden | CloudProfile + Project + credentials + optional shoot |

`kubectl delete xallotment/garden --cascade=foreground` blocks until every
descendant is reconciled away; foreground cascading deletion recurses through
nested XRs via `blockOwnerDeletion` ownerReferences. (The XRDs still carry
`defaultCompositeDeletePolicy: Foreground`, but in `apiextensions.crossplane.io/v2`
that field is deprecated and only affects claim-based deletion — claims aren't
used here.)

## `runtime-*` naming convention

Resources that target or exist on the runtime cluster (vs the kind bootstrap
cluster or the virtual garden API) use a `runtime-` prefix:

| Name | Composition | Purpose |
|---|---|---|
| `runtime-connection` | Infra | Connection secret with runtime kubeconfig (in `crossplane-system`) |
| `helm-providerconfig-runtime` | Infra | Helm ProviderConfig targeting the runtime cluster |
| `k8s-providerconfig-runtime` | Infra | Kubernetes ProviderConfig targeting the runtime cluster |
| `runtime-admin-sa` / `-crb` / `-token` | Workload | cluster-admin ServiceAccount + token for cloud-CLI-free kubeconfig |
| `runtime-crossplane` | Workload | Crossplane Helm release on the runtime cluster |
| `runtime-provider-k8s` | Workload | provider-kubernetes deployed on the runtime |
| `runtime-providerconfig-virtual` | Workload | ProviderConfig on the runtime targeting the virtual garden API |

## Composition details

### Infrastructure (`infra-{provider}`)

Pipeline — GCP: `load-versions → sequence → patch-and-transform → auto-ready`;
AWS: `load-versions → render-zone-resources → patch-and-transform → auto-ready → sequence`.
The connection secret propagates the runtime kubeconfig as `runtime-connection`
in `crossplane-system`.

- **AWS (~37 MRs)**: VPC (`10.0.0.0/16`) + secondary CIDRs (`100.64.0.0/16` pods,
  `10.250.0.0/16` shoots), public/private/pod subnets (2 AZs), IGW, NAT gateway,
  EIP, route tables, EKS cluster + node group, IAM roles (cluster, node, EBS CSI),
  OIDC provider, EBS CSI add-on, VPC CNI add-on with custom networking, ENIConfigs,
  pod-CIDR probe Jobs, Route 53 private zone, Helm + K8s ProviderConfigs. Singleton
  resources live in `compositions/aws/infra.yaml`; repeated two-zone resources
  (subnets, RTAs, ENIConfigs, probes) render from `platform/templates/infra-aws.tmpl`.
- **GCP (~6 MRs)**: regional GKE cluster (`gcpNodesPerZone: 3` × 2 zones = 6
  `e2-standard-4` nodes), Cloud DNS private zone, Cloud Router (shoot NAT), GCP +
  Helm + K8s ProviderConfigs.

### Workload (`workload-{provider}`)

Pipeline: `load-versions → sequence → fetch-sa-key → create-provider-resources
(go-templating) → patch-and-transform → auto-ready`.

| Resource | Type | Purpose |
|---|---|---|
| `default-storage-class` (AWS only) | Object | gp3 StorageClass for EKS |
| `runtime-admin-sa/crb/token` | Objects | ServiceAccount + token for cloud-CLI-free kubeconfig |
| `ns-garden` | Object | Garden namespace on the runtime |
| `cert-manager` | Helm Release | TLS certificate management |
| `gardener-operator` | Helm Release | Manages the Garden lifecycle |
| `runtime-crossplane` | Helm Release | Crossplane bridge on the runtime |
| `runtime-provider-k8s` | Object | provider-kubernetes on the runtime |
| `runtime-providerconfig-virtual` | Object | ProviderConfig targeting the virtual garden API |
| Credential secrets (2) | go-templated Objects | Cloud-provider + DNS credentials in the garden namespace |

Go-templating handles the credential secrets because GCP's `serviceaccount.json`
key contains a dot that Crossplane patch references cannot address, and AWS
secrets need provider-specific key formatting.

### Garden (`garden-{provider}`)

Pipeline: `load-versions → fetch-extra-resources → create-garden (go-templating)
→ create-extensions (go-templating) → auto-ready`.

| Resource | Type | Purpose |
|---|---|---|
| `garden-core` | Object | The Garden CR the operator reconciles |
| `dns-secret` | Object | DNS credential Secret on the virtual garden (outlives XVirtualGarden) |
| `default-domain-secret` | Object | Default-domain Secret read on every controllerinstallation-seed reconcile (must outlive the Seed) |
| `seed-registration-vap` / `-vapb` | Objects | ValidatingAdmissionPolicy + Binding gating Seed CREATE on the `allow-seed-registration` marker |
| `ext-provider-{aws/gcp}` | Object | Cloud infrastructure / DNS / control plane / workers extension |
| `ext-net-calico` | Object | Calico CNI networking |
| `ext-os-gardenlinux` / `ext-os-ubuntu` | Objects | OS image extensions |
| `ext-shoot-cert` / `ext-shoot-dns` | Objects | Shoot cert / DNS extensions |
| `ext-namespace-viewer` / `-binding` | Objects | ClusterRole + binding for extension SA namespace access |

The `ext-*` Objects are Gardener
[Extensions](https://gardener.cloud/docs/gardener/extensions/). They use
`deletionPolicy: Orphan`; the two Secret Objects use outer
`Delete` + inner `Orphan` (see
[teardown ordering](../explanation/teardown-ordering.md#why-some-resources-are-orphaned-not-deleted)).
AWS adds the NLB annotation (`service.beta.kubernetes.io/aws-load-balancer-type: nlb`)
to avoid orphaned security groups.

### Seed (`seed-{provider}`)

Pipeline: `load-versions → create-gardenlet (go-templating) → auto-ready`.

| Resource | Type | Purpose |
|---|---|---|
| `seed-gardenlet` | Object (double-nested) | [Gardenlet](https://gardener.cloud/docs/gardener/concepts/gardenlet/) CR — deploys gardenlet, registers the seed |
| `seed-cr` | Object (double-nested, Observe+Delete) | Delete-hook: deletion triggers gardenlet's drain |
| `seed-registration-permit` | Object (double-nested) | `allow-seed-registration` marker ConfigMap |
| `gardenlet-deploy-hook` | Object (Observe+Delete) | Deletes the gardenlet Deployment after the drain |
| `gardenlet-deploy-used-by-seed-cr` | ClusterUsage | Holds the gardenlet Deployment until the Seed CR is gone |

### Virtual Garden (`virtual-{provider}`)

Pipeline: `load-versions → sequence → fetch-extra-resources →
create-provider-resources (go-templating) → auto-ready`. All ~8 resources are
[double-nested](../explanation/double-nesting.md) Objects:

| Resource | Purpose |
|---|---|
| `virtual-cloudprofile` | Cloud regions, zones, machine types, k8s versions |
| `virtual-project` | Gardener project namespace |
| `virtual-cloud-provider-secret` | Cloud credentials on the virtual garden |
| `virtual-dns-secret` | DNS credentials (internal-domain) |
| `virtual-default-domain-secret` | Default domain (shoot auto-DNS) |
| `virtual-credentials-{provider}` | Cloud CredentialsBinding |
| `virtual-credentials-dns-{provider}` | DNS CredentialsBinding |
| `virtual-default-shoot` | Optional `eval` shoot (when `createShoot: "true"`) |

## Lifecycle metadata

Provider-managed infrastructure gets deterministic lifecycle metadata where the
cloud API exposes native tags/labels. AWS uses tag keys `allotment.cluster`,
`allotment.provider`, `allotment.created-by`, and optional `allotment.expires-at`;
GCP uses label-safe keys `allotment_cluster`, `allotment_provider`,
`allotment_created_by`, and optional `allotment_expires_at`. Values come from
`deploy/config.yaml` (`clusterName`, `provider`, `createdBy`, optional
`expiresAt`). Resources without native tag fields are still covered by
deterministic names for `task verify-clean`.
