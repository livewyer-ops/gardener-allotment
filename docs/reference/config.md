# Configuration reference

`deploy/config.yaml` is a Crossplane `EnvironmentConfig` and the single
user-editable file. Copy a provider example and edit it:

```bash
cp deploy/config-gcp.yaml.example deploy/config.yaml   # GCP
cp deploy/config-aws.yaml.example deploy/config.yaml   # AWS
```

The example files are the canonical, commented templates. The full schema:

```yaml
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: allotment-config
data:
  provider: gcp              # gcp | aws
  projectId: my-project      # GCP project ID, or AWS 12-digit account ID
  region: europe-west1       # cloud region
  zones:                     # runtime zones in the region; see "Choosing zones"
    - europe-west1-b
    - europe-west1-c
  clusterName: allotment     # resource name prefix
  createdBy: allotment       # lifecycle metadata (tag/label value)
  # expiresAt: "2026-06-30"  # optional lifecycle metadata
  dnsDomain: allotment.garden.internal
  createShoot: "false"       # "true" to also create the eval shoot
  # GCP-only:
  vpcNetwork: default
  gcpNodesPerZone: 3
  # AWS-only:
  awsProfile: default
  awsGardenlinuxAmi: ami-032075382f7aac30e # Garden Linux OS AMI for this region
  awsNodesPerZone: 2
```

## Fields

| Field | Providers | Required | Notes |
|---|---|---|---|
| `provider` | both | yes | `gcp` or `aws`; selects the composition set |
| `projectId` | both | yes | GCP project ID, or AWS 12-digit account ID without dashes |
| `region` | both | yes | single cloud region |
| `zones` | both | yes | GCP: one or more zones in `region`; AWS: two to four AZ names from `region` that are available in your account |
| `clusterName` | both | yes | prefix for created resources and tags/labels |
| `dnsDomain` | both | yes | private evaluation DNS domain |
| `createShoot` | both | yes | `"false"` landscape only, `"true"` adds the `eval` shoot |
| `createdBy` | both | no | lifecycle metadata value (default `allotment`) |
| `expiresAt` | both | no | optional lifecycle metadata (e.g. `"2026-06-30"`) |
| `vpcNetwork` | GCP | yes | VPC network name (e.g. `default`) |
| `gcpNodesPerZone` | GCP | no | runtime nodes per configured zone (default `3`) |
| `awsProfile` | AWS | yes | AWS CLI profile for the bootstrap identity |
| `awsGardenlinuxAmi` | AWS | yes | region-specific Garden Linux AMI for the CloudProfile; Garden Linux is the operating system name |
| `awsNodesPerZone` | AWS | no | runtime nodes per configured zone (default `2`; max size adds one surge node per zone) |

Quoted string values (`createShoot`, `expiresAt`) are intentional - they are
consumed as strings by the compositions.

## Choosing zones

For GCP:

```bash
gcloud compute zones list --filter='region:europe-west1' --format='value(name)'
```

For AWS:

```bash
aws ec2 describe-availability-zones --region eu-west-1 \
  --query 'AvailabilityZones[].ZoneName' --output text
```

AWS Availability Zone names are account-mapped. Do not assume another account's
`eu-west-1a` is the same physical zone, and do not assume every public example
zone exists for your account. GCP zone names are stable, but capacity or quota can
still make a selected zone fail during GKE creation.

How these values flow into the platform is described in the
[convergence model](../explanation/convergence-model.md#configuration-flows-from-one-file);
how they map to cloud tags/labels is in the
[resource reference](resources.md#lifecycle-metadata).
