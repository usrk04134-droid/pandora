# ADR 007: Nix Flakes for managing build systems and dependency management

## Status

Accepted

## Context

The Godzilla DevOps team needs a reliable and consistent way to manage builds, build dependencies, containers, test environment and test frameworks for both the software and hardware-related components in the CI/CD, SIL and HIL setup. Dependency management should also be reproducible across environments with the possibility of version traceability.

## Decision

Nix Flakes SHALL be used for managing the build & test systems and their dependencies in all environments. Nix Flakes allow for a structured, simplistic and deterministic approach to managing dependencies, ensuring that the same versions are used across different systems and builds.

## Consequences

### Positive

- Reproducible builds across different environments.
- Reproducible environments across different systems.
- Easy version pinning and rollback capabilities.
- Version traceability and reproducibility.
- Declarative management of dependencies reduces the risk of mismatches.
- Aligns with the choice done by the Adaptio product.

### Negative

- Some team members may find Nix Flakes challenging to learn and adopt.
- Nix cmd and flakes is still marked as experimental.
- Integration with non-Nix ecosystems may require additional effort.
- Quite steep learning curve.

## References

- [NixOS Wiki Flakes](https://nixos.wiki/wiki/Flakes)
- [Nix.dev concepts Flakes](https://nix.dev/concepts/flakes.html)
