# Security Policy

Allotment creates real cloud infrastructure and can mint broad-permission
evaluation credentials. Use a dedicated throwaway cloud account or project, and
run `task teardown` plus `task deauth` when finished.

## Reporting a Vulnerability

Do not open a public issue for a vulnerability.

Report security concerns privately through GitHub private vulnerability
reporting if it is enabled for this repository. If that is unavailable, contact
LiveWyer privately at `security@livewyer.com`.

Please include:

- Affected component or file path
- Steps to reproduce
- Expected impact
- Any relevant logs with secrets redacted

We will acknowledge credible reports, investigate privately, and coordinate a
fix before public disclosure.

## Supported Use

This project is an evaluation sandbox, not a production platform. Security fixes
focus on preventing credential exposure, unexpected cloud-resource retention,
and unsafe defaults for the documented evaluation workflow.
