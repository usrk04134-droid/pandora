# ADR 011: Python as the language of choice for automation, test programs, and pipeline job support

## Status

Accepted

## Context

The DevOps team requires a standardized language for automating tasks, writing test programs for HIL, and supporting pipeline job execution. The language should be easy to learn, versatile, and widely supported across the tools and systems we use. Additionally, the language needs to support hardware interfacing, cloud infrastructure, and CI/CD pipeline needs.

## Decision

Python is chosen as the primary language for writing automation scripts, HIL test programs, and support programs for pipeline jobs. Python is a versatile, high-level language that is well-suited for the varied tasks in DevOps, including system automation, API interaction, hardware communication, and test scripting.

## Consequences

### Positive

- Python has extensive libraries for automation, hardware interfacing (e.g., for HIL), cloud interactions, and CI/CD pipelines.
- Python is easy to learn and widely adopted, reducing onboarding time for new team members.
- Strong integration with Pytest for test automation and readily available packages like `requests` and `fabric/paramiko` for handling APIs and SSH tasks.
- Python’s cross-platform support ensures compatibility across different operating systems and environments, including NixOS, Windows (for Siemens TIA), and AKS.

### Negative

- Python's performance may be slower than lower-level languages for certain hardware-intensive operations, though performance is typically acceptable for most automation tasks.
- Managing Python environments and dependencies across multiple systems can be challenging without careful versioning and tooling (mitigated through Nix Flakes).
