# Task reference

`task help` is the authoritative list — it prints every target with descriptions
and the current provider. This page groups them by lifecycle phase; descriptions
live in `task help` so they cannot drift.

## Targets by phase

**Set up & validate**

- `bootstrap-identity` — create disposable cloud credentials for evaluation
- `load-identity` — load existing credentials into Crossplane secrets
- `build` — validate and assemble a provider-specific manifest bundle/inventory under `private/build/`
- `validate` — lint YAML, parse manifests, validate Taskfiles, schema-validate where schemas exist
- `validate-render` — render AWS/GCP compositions with the Crossplane CLI and compare expected resources

**Run**

- `install` — full deployment (~25 min, +15 min with `createShoot`)
- `status` — claim, child XRs, managed resources, recent warnings
- `validate-live` — Chainsaw post-install checks against the control-plane and runtime clusters
- `observability` — runtime readiness, API metrics, Garden pods, warning events

**Access**

- `kubeconfig` — extract the runtime cluster kubeconfig
- `dashboard` — print the Dashboard URL + token and port-forward (http://localhost:8443)
- `token` — print the Dashboard login token

**Tear down**

- `teardown` — `kubectl delete xallotment --cascade=foreground`; ClusterUsages cascade through every child in order (~15 min)
- `deauth` — remove cloud credentials (guarded: refuses while resources exist)
- `verify-clean` — read-only audit for likely cloud leftovers
- `clean-private` — remove generated logs and kubeconfigs, keep credentials

## Provider dispatch

`Taskfile.yml` derives `PROVIDER` from `deploy/config.yaml` and dispatches the
provider-specific identity tasks:

| Operation | Target | Dispatches to |
|---|---|---|
| Bootstrap disposable identity | `task bootstrap-identity` | `identity:bootstrap-identity-<provider>` |
| Load credentials | `task load-identity` | `identity:load-identity-<provider>` |
| Remove credentials | `task deauth` | `identity:deauth-<provider>` |

Provider-agnostic tasks (`install`, `teardown`, `status`, `kubeconfig`, …) use
`PROVIDER` to select the correct bootstrap files, compositions, and claims at
runtime. The public interface is `Taskfile.yml`; provider helper logic lives in
`.tasks/`.
