## Summary

## Validation

- [ ] `task validate`
- [ ] Live `task install` / `task teardown` cycle, or reason not run:

## Risk

- [ ] Touches cloud resources, credentials, or teardown behavior
- [ ] Touches Crossplane compositions or XRDs
- [ ] Documentation-only change

## Notes

Do not include secrets, kubeconfigs, access keys, service-account keys, or full
tokens in this PR.
