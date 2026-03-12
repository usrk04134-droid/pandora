# ADR 014: Windows virtual machine for Siemens TIA on HIL PC

## Status

Proposed

## Context

The HIL system needs to manage the system PLC (Programmable Logic Controller) via Siemens TIA (Totally Integrated Automation) software. Siemens TIA only runs on Windows, but the test PCs are using NixOS (Linux) as their operating system.

## Decision

A Windows virtual machine SHALL be deployed on the HIL test PC (running NixOS as the host OS). The virtual machine SHALL host Siemens TIA to manage the PLC during manual HIL testing. This ensures that we can maintain our preferred NixOS environment while still supporting the necessary proprietary tools.

## Consequences

### Positive

- Ensures compatibility with Siemens TIA for PLC management.
- Allows us to keep NixOS as the host OS, benefiting from its reproducibility and declarative configuration.
- Virtualization isolates Windows, reducing potential conflicts with the NixOS environment.
- Removes the potential need of a separate Windows system in the HIL test setup.

### Negative

- Performance overhead due to virtualization.
- No interoperability between cloud jobs and PLC management.
- Increased complexity in managing the virtual machine alongside the NixOS system.
- Additional licensing and maintenance requirements for Windows and TIA Portal.

## References

- [NixOS Wiki VMWare](https://nixos.wiki/wiki/Virtualization)
- [Siemens TIA Portal](https://www.siemens.com/global/en/products/automation/industry-software/automation-software/tia-portal.html)
