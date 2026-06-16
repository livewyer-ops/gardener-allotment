# Permissions and Endpoint Posture

Allotment is an evaluation sandbox. The supported permission model is
resource-level admin in a disposable cloud account or project, not production
least privilege. Keep each evaluation in a dedicated account/project and delete
the bootstrap identity with `task deauth` after `task teardown`.

This shape is intentional for the current product: Crossplane and Gardener both
create infrastructure, identity, DNS, storage, and Kubernetes resources across a
full landscape. A narrow custom policy that is not continuously derived and
validated against both providers would be more fragile than honest, documented
evaluation-admin credentials.

## Bootstrap Cloud Identity

`task bootstrap-identity` creates a disposable identity that can create the
runtime cluster, networking, DNS, IAM/service accounts, and Gardener backup
resources. `task load-identity` can also load an identity supplied by the user,
provided that identity has equivalent resource-level admin permissions.

### GCP

The bootstrap service account receives:

| Role | Why it is currently used |
|---|---|
| `roles/compute.admin` | GKE networking, firewalls, disks, and shoot worker infrastructure |
| `roles/container.admin` | GKE runtime cluster management |
| `roles/dns.admin` | Private Cloud DNS zones and records |
| `roles/storage.admin` | Gardener backup bucket resources |
| `roles/iam.serviceAccountAdmin` | Workload service account creation |
| `roles/iam.serviceAccountKeyAdmin` | Service account keys for Gardener credentials |
| `roles/iam.serviceAccountUser` | GKE default compute service account usage |
| `roles/resourcemanager.projectIamAdmin` | IAM bindings for created service accounts |
| `roles/serviceusage.serviceUsageAdmin` | API enablement during bootstrap |

### AWS

The bootstrap IAM user receives:

| Policy | Why it is currently used |
|---|---|
| `AmazonEC2FullAccess` | VPC, subnets, gateways, route tables, security groups, EBS, and worker networking |
| `AmazonRoute53FullAccess` | Private hosted zone and records |
| `IAMFullAccess` | EKS cluster/node roles, OIDC provider, IRSA, and related attachments |
| `AmazonS3FullAccess` | Gardener backup bucket resources |
| Inline `eks:*` | EKS cluster, node group, add-on, and auth resources |

## Kubernetes RBAC

`bootstrap/providers-common.yaml` grants `cluster-admin` to the
provider-kubernetes and provider-helm pods. This lets Crossplane manage
namespaces, CRDs, Helm releases, secrets, and cross-namespace resources during
the evaluation flow.

The runtime cluster also gets a long-lived admin service account so `task
kubeconfig` and `task dashboard` work without cloud-specific kubeconfig helpers
after the initial identity setup.

## Public Endpoint Posture

AWS EKS currently sets `endpointPublicAccess: true` because the Crossplane
control plane runs in local kind and must reach the runtime API server from the
operator's workstation. GCP uses the default public control-plane posture for the
same reason. There are no authorized-network restrictions in the evaluation
path.

This is acceptable only for throwaway evaluation environments. A restricted mode
would need one of:

- A cloud-hosted Crossplane control plane inside the runtime network
- Configurable authorized networks for the operator's current public IP
- Private connectivity from the local control plane to the cloud VPC

## Least-Privilege Follow-Up

Do not hand-roll a partial "least privilege" policy from memory. The
narrow-permissions workstream should derive provider policies from observed
managed resources, Gardener provider documentation, and repeated AWS/GCP live
validation, then split the current bootstrap identities into:

- Bootstrap identity: creates only the local ProviderConfig credentials and
  minimum cloud prerequisites
- Reconcile identity: scoped to the exact resources Crossplane manages
- Gardener credentials: scoped to the resources Gardener needs for seeds,
  shoots, and backups

Useful upstream references for that workstream:

- [Gardener AWS provider operations](https://gardener.cloud/docs/extensions/infrastructure-extensions/gardener-extension-provider-aws/operations/)
- [Gardener GCP provider usage](https://gardener.cloud/docs/extensions/infrastructure-extensions/gardener-extension-provider-gcp/usage/)
- [Gardener GCP provider operations](https://gardener.cloud/docs/extensions/infrastructure-extensions/gardener-extension-provider-gcp/operations/)
