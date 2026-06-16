# Contributing

See [README.md](README.md) for prerequisites.

Participation is covered by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Workflow

1. Fork and clone
2. Create a branch (`feature/`, `fix/`, or `docs/` prefix)
3. Run `task validate`
4. Test risky changes with a full `task install` / `task teardown` cycle
5. Open a pull request

Runtime clusters incur cloud charges. Always run `task teardown` after testing.
The `private/` directory is gitignored -- never commit its contents.

## What to Contribute

- Bug fixes, documentation, region support, Gardener extensions
- **Open an issue first** for: multi-cloud support, DNS alternatives, version upgrades

## Guidelines

### Compositions

- Each Composition targets one API server (kind, GKE, or virtual garden)
- Use `function-sequencer` for resource ordering within a Composition; cross-Composition teardown ordering is modeled with `ClusterUsage`
- Use `function-go-templating` only when P&T can't handle it (e.g., dotted key names)
- Teardown deletes the root `XAllotment` with foreground cascade -- see the `teardown` task in `Taskfile.yml`

### Taskfile

- All operations go through Task targets
- `Taskfile.yml` is the public interface; provider-specific helper logic lives in `.tasks/`
- Install project tools with `aqua install` and put `$(aqua root-dir)/bin` on
  `PATH`; keep Docker as the only explicit non-aqua runtime prerequisite
- Readiness polling, not bare `sleep`
- Teardown must remove all billable cloud resources

### Configuration

- `deploy/config.yaml` is the single source of truth
- Claims live under `deploy/claims/<provider>/`
- Do not commit generated credentials, kubeconfigs, or logs from `private/`

See [docs/explanation/convergence-model.md](docs/explanation/convergence-model.md) for architecture details.

## License

Contributions are licensed under [Apache License 2.0](LICENSE). Please keep
discussions respectful and focused on the work.
