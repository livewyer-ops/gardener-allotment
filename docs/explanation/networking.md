# Networking and seed registration

*Why the CIDRs are laid out the way they are, on each provider.*

The [gardenlet](https://gardener.cloud/docs/gardener/concepts/gardenlet/)
registers the runtime cluster as a Gardener seed, which enables shoot creation.
Gardener requires the seed's node, pod, and service networks to be
[non-overlapping](https://gardener.cloud/docs/getting-started/common-pitfalls/),
and it validates the declared pod network against the pods it actually sees — so
the network layout is not cosmetic.

## Shared configuration

- **Runtime zones** — `deploy/config.yaml` must specify exactly two zones in the
  selected region. AWS uses them for public/private/pod subnets, ENIConfigs, and
  pod-CIDR probes; GCP uses them for runtime `nodeLocations`. Garden and Seed
  zone lists render from the same config.
- **DNS secrets** — `internal-domain` (`gardener.cloud/role: internal-domain`)
  for Gardener infrastructure; `default-domain`
  (`gardener.cloud/role: default-domain`) for shoot auto-DNS.
- **DNS zones** — private on both providers (GCP Cloud DNS, AWS Route 53 PHZ).
  Shoots share the seed VPC, so the private zones are visible to shoot workers.
- **ACME** — `generateControlPlaneCertificate: false`, because private DNS cannot
  pass the ACME challenge (staging certs; browser warnings).
- **Ingress** — seed ingress at `seed.{dnsDomain}`.

## GCP network CIDRs

Pods `10.2.0.0/16` and services `10.3.0.0/20` are pinned via GKE
`ipAllocationPolicy`. Nodes use `10.128.0.0/9` (the GKE default VPC range, not
pinnable). Because GKE lets you pin pod/service CIDRs directly, GCP needs no
secondary-CIDR machinery.

## AWS network CIDRs

- Nodes `10.0.0.0/16` (VPC primary)
- Pods `100.64.0.0/16` (VPC secondary CIDR, via VPC CNI custom networking)
- Services `172.20.0.0/16` (the EKS default for a VPC in `10.0.0.0/8`)
- Shoot workers `10.250.0.0/16` (a tertiary CIDR, same RFC 1918 class as primary)

On EKS the VPC CNI assigns pod IPs from the node's subnet by default, which would
overlap the node CIDR. To give pods a non-overlapping CIDR, Allotment uses VPC CNI
**custom networking** with a secondary CIDR — the AWS-recommended pattern. (An
overlay CNI such as Cilium or Calico on the seed is a possible alternative that
would decouple pod IPs from the VPC and remove the secondary CIDR, ENIConfigs,
and probes.)

### The AWS pod-CIDR gate

The AWS infra sequencer runs *after* resource rendering and holds the managed
node group until the VPC CNI add-on and ENIConfigs are ready. Two runtime Jobs
then prove that non-hostNetwork pod IPs in both configured zones fall inside
`100.64.0.0/16`. `XInfra` does not become Ready until both probes succeed — so a
Seed is never registered with a pod network that does not match reality. A hang
here is the gate working; see
[troubleshoot-and-recover](../how-to/troubleshoot-and-recover.md).

## Default shoot networking

When `createShoot: "true"`, XVirtualGarden creates a shoot named `eval`. Both
providers share the seed VPC so shoot workers resolve the private DNS zone — no
domain ownership needed.

**GCP shoot** — uses the seed's default VPC (`vpc.name: default`) with Cloud
Router for NAT; workers in `172.16.0.0/16` (outside the default VPC's
`10.128.0.0/9` auto-subnet range); 1–2 `n1-standard-2` workers, Garden Linux,
Calico.

**AWS shoot** — uses the seed VPC (`vpc.id`) with the `10.250.0.0/16` secondary
CIDR for workers (`10.250.0.0/19`), public `10.250.96.0/22`, internal
`10.250.112.0/22`. The shoot node CIDR is disjoint from the seed CIDRs, so no VPN
double-NAT is needed; Gardener creates its own NAT gateway, subnets, and route
tables within the shared VPC. 1–2 `m5.xlarge` workers, Garden Linux, Calico.
