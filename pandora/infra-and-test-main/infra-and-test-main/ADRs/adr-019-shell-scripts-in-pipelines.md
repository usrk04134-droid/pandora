# ADR 019: Implement Complex Job Script Logic as Shell Scripts

## Status

Proposed

## Context

Pipeline jobs often require various actions performed through script steps. When these scripts grow in complexity and size, embedding them directly in job templates becomes cumbersome and hard to maintain.

Complex inline scripts present several challenges:

- Limited readability due to lack of syntax highlighting in pipeline YAML templates
- Difficult debugging and testing process
- No access to linting tools when embedded in pipeline YAML templates
- Hard to reuse across different pipeline jobs
- Hidden dependencies through implicit use of environment variables

Moving complex script logic to standalone shell script files addresses these issues while improving maintainability.

## Decision

We SHALL aim to implement complex job script logic as standalone shell script files rather than embedding scripts directly inside job templates.

Script files should:

- Be stored in a consistent location (e.g. `.gitlab-ci/scripts`) within the repository
- Include proper documentation and usage examples
- Be written with appropriate error handling
- Use explicit input arguments instead of relying on environment variables or other implicit data sources

Job templates should reference these script files rather than containing complex logic directly.

## Consequences

### Positive

- Increased testability as scripts can be executed and debugged locally
- Better developer experience with syntax highlighting in IDEs
- Ability to leverage linting tools both locally and in CI pipelines
- Improved code reusability across different pipeline jobs
- Better version control and code review process for script changes
- Cleaner, more readable pipeline configuration files

### Negative

- Additional boilerplate code needed to maintain consistent logging, error handling, input arguments, and output formatting
- Slight increase in repository complexity with additional files
- Potential overhead in managing script permissions and execution environments

## References
