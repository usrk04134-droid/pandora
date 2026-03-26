# ADR 0010: Pytest as integration test framework

## Status

Proposed

## Context

The Godzilla DevOps team requires a robust and flexible test framework for writing and executing tests for the SIL & HIL setup. The framework should be easily extensible, widely supported, and support integration with different test systems and tooling we need.

## Decision

Pytest SHALL be used as the test framework for SIL & HIL verification. Pytest provides a simple yet powerful way to write tests, supports fixtures and plugins, supports communication protocols we need (JSON-RPC) and is highly compatible with the Python ecosystem, making it a suitable choice for SIL & HIL testing.

## Consequences

### Positive

- Easy-to-write and maintain test cases with a rich plugin ecosystem.
- Strong community support and documentation.
- Pytest fixtures can be used to set up complex SIL & HIL scenarios.

### Negative

- Pytest may not natively support all hardware interfaces out-of-the-box, requiring custom integration.
- Non-Python developers may have a learning curve in adopting the framework.

## References

- [pytest: helps you write better programs](https://docs.pytest.org/en/stable/)
- [Python JSON-RPC](https://json-rpc.readthedocs.io/en/latest/)
