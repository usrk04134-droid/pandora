# ADR 013: Local GitLab runner in the HIL, deployed on NixOS

## Status

Accepted

## Context

HIL testing requires direct interaction with hardware and specific local configurations, which makes cloud-based runners unsuitable for these jobs. Each HIL instance requires its own isolated runner for running tests locally on the hardware.

## Decision

A local GitLab runner SHALL be deployed on NixOS for each HIL setup. These runners will be dedicated (tagged) to running HIL-specific test jobs and directly interfacing with the hardware systems under test.

## Consequences

### Positive

- Ensures that HIL tests are run close to the hardware, reducing latency and improving test reliability.
- NixOS ensures a reproducible and consistent runner environment across HIL setups.
- Localized runners reduce the need for complex networking or external dependencies.
- Connectivity from GitLab requires no firewall configuration nor opening of ports.

### Negative

- Requires maintenance of multiple local runners across different HIL instances.
- Local testing requires disabling of runner.
- Additional setup and monitoring are needed to ensure all local runners are operational.
- Debugging issues with hardware-specific tests may require physical intervention.
- Lacking manual booking system for manual test runs (runner will need to be manually paused from accepting new jobs and re-enabled when done).
- No support for automatic detection of when a runner is in active use manually (can lead to manual use colliding with automatic jobs).
- GitLab considers its runners as ephemeral (problem when jobs need SAME runner in sequence).

## References

- [NixOS Wiki GitLab Runner](https://nixos.wiki/wiki/Gitlab_runner)
- [GitLab runner tags](https://docs.gitlab.com/ee/ci/runners/configure_runners.html#control-jobs-that-a-runner-can-run)
