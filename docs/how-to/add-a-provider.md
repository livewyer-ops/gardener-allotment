# Add a new cloud provider

This guide assumes you understand the [convergence model](../explanation/convergence-model.md)
and [resource reference](../reference/resources.md). It adds a third provider
alongside the existing GCP and AWS implementations.

## Steps

1. **Bootstrap providers**: create `bootstrap/providers-<provider>.yaml` with
   the cloud-specific Crossplane providers.
2. **Versions**: create `platform/configs/versions-<provider>.yaml` with
   provider-specific versions (mirror `versions-aws.yaml` / `versions-gcp.yaml`).
3. **Compositions**: create six in `platform/compositions/<provider>/`:
   - `allotment.yaml`: root: emits the cloud ProviderConfig + the five child
     XRs, ordered by ClusterUsages.
   - `infra.yaml`: runtime cluster + networking + DNS.
   - `workload.yaml`: operator, credentials, cert-manager, runtime bridge.
   - `garden.yaml`: Garden CR + DNS Secret + Extension CRs.
   - `seed.yaml`: Gardenlet + Seed CR delete-hook.
   - `virtual.yaml`: CloudProfile, project, credentials, optional shoot.
4. **Claim**: create `deploy/claims/<provider>/allotment.yaml`: an `XAllotment`
   with `compositionSelector.matchLabels.provider: <provider>`.
5. **Config example**: create `deploy/config-<provider>.yaml.example` from the
   [config reference](../reference/config.md).
6. **Identity tasks**: add `identity:bootstrap-identity-<provider>`,
   `identity:load-identity-<provider>`, and `identity:deauth-<provider>` in
   `.tasks/identity.yml`.

## Things to get right

- **Networking**: the seed's node/pod/service CIDRs must not overlap, and the
  declared pod network must match the pods Gardener observes. See
  [networking](../explanation/networking.md) for how AWS and GCP each solve this;
  a new provider needs its own answer.
- **Teardown ordering**: reuse the ClusterUsage chain from the existing root
  compositions; do not reach for `function-sequencer` at the XAllotment layer
  ([teardown ordering](../explanation/teardown-ordering.md)).
- **Virtual garden access**: follow the
  [double-nesting](../explanation/double-nesting.md) pattern for any
  virtual-garden resources.
- **Cleanup**: add deterministic names/tags and extend `task verify-clean`
  ([reference/permissions](../reference/permissions.md) covers the credential
  model the new provider needs).

Validate the new provider with a full `task install` / `task teardown` /
`task verify-clean` cycle (with and without `createShoot`) before advertising it
as supported.
