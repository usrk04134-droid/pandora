# ADR 012: NixOS as the operating system for the HIL test PC

## Status

Accepted

## Context

We need a reliable, reproducible, and declaratively configured operating system for the test PCs connected to the Hardware-In-the-Loop (HIL) system. The test PC is a crucial part of the HIL setup and needs to be lightweight, easily configurable, easily deployable and highly deterministic. We also need to support the requirement of running different software components and tools in an isolated environment without excessive overhead along with supporting both local (via local keyboard & display) and remote (via GitLab) use of the system.

## Decision

NixOS SHALL be used as the operating system for the test PCs in the HIL setup. NixOS is a Linux distribution based on a declarative model and offers reproducible builds. Its package manager, Nix, ensures that each component installed on the system is isolated and self-contained, providing a robust environment for HIL testing.

## Consequences

### Positive

- Reproducibility and immutability of system configurations, ensuring identical environments across all HIL systems.
- Same OS as used by the Adaptio Software product.
- Easy rollback and system upgrades, reducing potential downtime in case of failure.
- Remote deployment and rollback is builtin, simplifying tech stack.
- Strong dependency isolation, minimizing conflicts between software components.
- Supports multiple package versions as first class citizen.
- Atomic deployments and automatic rollback supported via deployment tools (`deploy-rs`).

### Negative

- Quite high learning curve for team members unfamiliar with NixOS.
- Limited support for certain proprietary drivers and software, which may require additional effort for compatibility.
- Nix cmd and flakes is experimental.

## References

- [Nix & NixOS](https://nixos.org/)
- [NixOS Wiki](https://wiki.nixos.org/wiki/NixOS_Wiki)
- [Why Should You Use NixOS?](https://itsfoss.com/why-use-nixos/)
