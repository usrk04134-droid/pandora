# ADR 016: Use Ruff for Python linting

## Status

Accepted

## Context

We need a consistent and efficient way to enforce coding standards across our Python projects.

## Decision

We SHALL use Ruff as the primary linter tool for all Python codebases. This choice is driven by its speed, comprehensive rule set, opinionated style, and ease of integration with existing workflows. We have decided to have `ruff.toml` inside the container, which will be default config for ruff lint, also other projects can have their own customizable `ruff.toml` if they need.

## Consequences

### Positive

- Improved consistency in code quality.
- Faster linting process due to Ruff's performance optimization.
- Simplified setup and maintenance of linting rules.
- A single tool for (opinionated) formatting and linting.

### Negative

- May require fixes to existing codebase to conform with the new style.
- May require additional configuration for specific project needs not covered by default settings.
- Potential learning curve for team members unfamiliar with Ruff.

## References

- [Ruff](https://astral.sh/ruff)
- [Ruff docs](https://docs.astral.sh/ruff/)
