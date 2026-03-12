# ADR 008: Bash as the interpreter of choice for pipelines

## Status

Accepted

## Context

CI/CD pipelines require a lightweight and flexible scripting language for defining and executing jobs. The language should be highly compatible with Unix-based systems, such as NixOS and the runners deployed in Kubernetes (AKS), and should provide robust shell scripting capabilities for managing the automation of build, deployment, and test processes.

## Decision

Bash is chosen as the interpreter for defining and running pipeline scripts. Bash is the de facto standard shell scripting language in Unix environments and provides the necessary flexibility to handle common CI/CD tasks, such as invoking build systems, running test suites, and deploying applications in Kubernetes clusters.

## Consequences

### Positive

- Bash is lightweight, fast, and readily available on all Unix-based systems, including NixOS and Kubernetes-based runners.
- It integrates seamlessly with other command-line tools commonly used in DevOps environments (e.g., `kubectl`, `terraform`, `docker`).
- Bash scripts are simple to write for basic tasks and highly customizable for more complex workflows.
- Bash is the default shell in GitLab pipelines and fully supported in GitLab CI/CD.

### Negative

- Bash can become difficult to maintain for more complex logic or operations, where more structured languages like Python might be better suited.
- Debugging bash scripts can be harder than higher-level languages due to limited error handling and verbosity.
- Portability can be an issue when moving bash scripts between Unix-like and non-Unix systems, though this is mitigated by our Unix-first environment (NixOS and AKS).

## References

- [Bash](https://www.gnu.org/software/bash/)
- [Bash Guide for Beginners](https://tldp.org/LDP/Bash-Beginners-Guide/html/)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [GitLab supported shell](https://docs.gitlab.com/runner/shells/)
