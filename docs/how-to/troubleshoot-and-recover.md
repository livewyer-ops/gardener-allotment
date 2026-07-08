# Operations and recovery

Allotment converges through Crossplane and Gardener, so install and teardown are
long-running and produce alarming-but-expected signals along the way. This page
explains which signals are normal, how to diagnose a lifecycle that looks stuck,
and how to recover safely.

The guiding rule: **Allotment is convergence-driven. Most "stuck" states resolve
themselves on the controllers' own retry schedule. Prefer waiting and re-running
the task over manual intervention.**

## Expected timings

| Phase | Typical | Notes |
|---|---|---|
| `task install`, landscape only | ~25 min | Runtime cluster + Gardener + seed registration |
| `task install`, `createShoot: "true"` | ~40 min | Shoot adds ~15 min after the landscape is ready |
| Runtime cluster creation (GKE/EKS) | ~10 min | Longest single install step |
| Garden deploy | ~10 min | `Garden: Processing`; transient `Garden: Error` is normal |
| `task teardown`, GCP | ~30 min | Slower than AWS; see seed deregistration below |
| `task teardown`, AWS | ~15-20 min | |
| Runtime cluster deletion | ~5 min | `remaining...` is normal here |

These are evaluation-environment observations, not guarantees. Wait at least to
the upper bound before treating a phase as stuck.

## Install - normal vs real problem

**Normal:**

- Long pauses at runtime-cluster creation and Garden deploy. Both are ~10 min.
- A transient `Garden: Error` condition that returns to `Processing` then
  `Succeeded`.

**AWS pod-CIDR gate (fail-closed by design):** AWS holds the managed node group
until the VPC CNI add-on and `ENIConfig`s are ready, then runs per-zone probe
Jobs that must observe pod IPs inside `100.64.0.0/16` before `XInfra` becomes
Ready. If custom networking never takes effect, the probes never pass, `XInfra`
never goes Ready, and `task install` waits out the 40-minute `XAllotment` wait
rather than registering a Seed with a pod network that does not match reality.
A hang here is the gate working - inspect with `task status` and the probe Jobs
in `kube-system` on the runtime cluster rather than forcing past it.

**Real problem:** a provider reporting unhealthy in `task status`, a managed
resource stuck `SYNCED=False` with an authentication or quota error in its
events, a GKE operation reporting zone capacity exhaustion, or a probe Job
failing with a non-`100.64` pod IP in its logs.

For the AWS pod-CIDR gate:

```bash
task kubeconfig
KUBECONFIG=private/runtime-kubeconfig kubectl get jobs,pods -n kube-system \
  | grep pod-cidr-probe
KUBECONFIG=private/runtime-kubeconfig kubectl logs -n kube-system \
  job/<cluster>-pod-cidr-probe-<slot>
```

The probe job names use the configured cluster name and zone slot, for example
`allotment-pod-cidr-probe-a`.

## Teardown - normal vs real problem

`task teardown` runs `kubectl delete xallotment garden --cascade=foreground`,
captures redacted diagnostics, and only removes the kind cluster if the cascade
succeeded. **On timeout it preserves kind so the controllers keep retrying and
the state can be inspected.**

The following are **expected** during seed deregistration and are *not* failures:

- **[gardenlet](https://gardener.cloud/docs/gardener/concepts/gardenlet/)
  `CrashLoopBackOff` in the `garden` namespace.** Once the Seed
  drain finishes, a restarted gardenlet container is denied Seed re-creation by
  the `seed-registration-permit` ValidatingAdmissionPolicy (the marker
  ConfigMap is already gone). It crashloops until the gardenlet Deployment
  delete-hook removes it. This guard is what prevents a restart from
  re-registering the Seed and orphaning seed-class `ManagedResource`s that would
  permanently block Garden's deletion DAG.
- **`SeedAuthorizer ... no relationship found` denials in the gardenlet log**
  (typically against `controllerdeployments` / `controllerinstallations`).
  During seed deregistration the dependency-graph edges the gardenlet relies on
  are being torn down concurrently, so these requests are transiently denied.
  They self-resolve once `controller-runtime` retries; the seed drain then
  proceeds. **Do not intervene** - on GCP this phase can sit apparently idle for
  several minutes before draining, which is why GCP teardown runs ~30 min.

**Real problem:** the cascade exceeds the 45-minute timeout with no progress
across two diagnostics captures, or a managed resource reports a hard cloud-API
error (quota, permission, dependency-violation) that is not clearing on retry.

## Diagnosing a stuck lifecycle

```bash
task status          # claim, child XRs, managed resources, recent warnings
task observability   # runtime readiness, API /metrics, Garden pods, warnings
task kubeconfig      # then inspect the runtime cluster directly
```

On teardown, `task teardown` also writes a redacted snapshot to
`private/logs/teardown-<timestamp>.log` (Crossplane, providers, XRs, managed
resources, recent warnings) before kind is removed - compare a stuck run against
a known-good one.

To watch the runtime side during seed drain:

```bash
KUBECONFIG=private/runtime-kubeconfig kubectl get managedresources -A
KUBECONFIG=private/runtime-kubeconfig kubectl logs -n garden deploy/gardenlet --tail=50
```

## Recovery

**Re-run the task.** Both `task install` and `task teardown` are idempotent.
After a teardown timeout the kind cluster is preserved and Crossplane keeps
reconciling, so re-running `task teardown` resumes the cascade.

**Confirm the cloud is clean** after teardown:

```bash
task verify-clean
```

This is a read-only audit for Allotment's deterministic resource names. If it
flags a leftover, delete that specific resource in the cloud console/CLI and
re-run it. A rare AWS NAT Elastic IP release race has been observed (about one
in several cycles) where the EIP remains allocated but unassociated after its
managed resource is gone; release it manually if `verify-clean` reports it.

**Stuck on cluster-scoped fluent `ClusterFilters`.** Historically the most
common deadlock: the colocated garden and seed each install the provider/OS
extensions, whose charts ship identical cluster-scoped fluent resources, and
during the seed drain the two owners fight (delete vs re-adopt). Teardown now
arms the `allotment-fluent-teardown-guard` ValidatingAdmissionPolicy: the
moment XSeed teardown starts, garden-side recreates are denied by admission,
so the drain completes. `task teardown` streams the resources still deleting;
if you ever see fluent resources named there for more than a few minutes,
capture diagnostics and report it - the guard should have made that
impossible.

**Break-glass (last resort).** If a teardown is genuinely deadlocked - diagnosed,
not assumed - seed-class `ManagedResource`s on the runtime cluster can be deleted
by hand to let Garden's deletion DAG proceed. Treat this as evidence of a bug to
fix in the compositions, not a routine step: **do not force-remove finalizers as
a first response, and never patch resource *state* to paper over a stuck
cascade.** Capture the diagnostics log first so the root cause can be addressed.

## Cleaning local state

```bash
task clean-private   # remove generated logs and kubeconfigs, keep credentials
task deauth          # remove the disposable cloud identity and local credentials
```

`private/` is gitignored; never commit its contents. See
[Permissions](../reference/permissions.md) for the credential model and
[teardown ordering](../explanation/teardown-ordering.md) for the design behind
the behaviours above.
