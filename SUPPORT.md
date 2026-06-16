# Support

Allotment is an evaluation repository for Gardener. It is not a supported
production platform.

## Usage Questions

Use GitHub Discussions if they are enabled for this repository. Otherwise open a
GitHub issue with:

- Provider: `gcp` or `aws`
- Non-secret `deploy/config.yaml` fields
- The task you ran
- Redacted output from `task status` or `task observability`

Do not include secrets, kubeconfigs, access keys, service-account keys, or full
tokens.

## Bugs

Open a bug report with reproducible steps. Include whether you ran:

```bash
task validate
task validate-live
task teardown
task verify-clean
```

## Security

For vulnerabilities or private safety concerns, follow [SECURITY.md](SECURITY.md)
instead of opening a public issue.

## Production Use

Allotment intentionally uses broad evaluation credentials and public control
plane defaults. For production Gardener deployments, use a production-oriented
platform and review the official Gardener documentation.
