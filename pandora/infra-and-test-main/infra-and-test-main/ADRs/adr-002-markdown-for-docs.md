# ADR 002: Markdown for documentation

## Status

Accepted

## Context

Maintaining up-to-date and easily accessible documentation is critical for collaboration within the Godzilla DevOps team. Documentation should be version-controlled and stored alongside code for traceability.

## Decision

Markdown MUST be used as the documentation format. All documentation SHALL be stored directly in the project repositories. This allows documentation to be versioned with the code, ensuring that any changes to the codebase are documented in the same commit.

## Consequences

### Positive

- Simplicity and readability of Markdown, making it accessible for all team members.
- Version-controlled documentation ensures consistency with code changes.
- Easy integration with tools like GitLab for inline display and review during pull requests.

### Negative

- Markdown may lack advanced formatting features compared to dedicated documentation systems.
- Documentation can become disorganized if not properly structured within the repository.

## References

- [GitLab Flavored Markdown (GLFM)](https://docs.gitlab.com/ee/user/markdown.html)
- [The Markdown Guide](https://www.markdownguide.org/)
