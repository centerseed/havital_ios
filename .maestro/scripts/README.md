# Maestro Scripts

## Artifact Cleanup

Use `run-maestro-with-artifact-cleanup.sh` instead of calling Maestro directly when you want leaner artifact folders.

Examples:

```bash
.maestro/scripts/run-maestro-with-artifact-cleanup.sh test .maestro/flows/onboarding-race-paceriz.yaml
.maestro/scripts/run-maestro-with-artifact-cleanup.sh test --include-tags boundary .maestro/flows/
.maestro/scripts/run-maestro-with-artifact-cleanup.sh cleanup-existing
```

Cleanup policy:

- Passing runs: remove all `screenshot-*.png`
- Failing runs: keep only `screenshot-❌-*.png`
- Always keep `ai-*`, `ai-report-*`, `commands-*`, and `maestro.log`
