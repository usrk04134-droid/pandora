# ADR 009: C4Model using PlantUML for visualization in GitLab

## Status

Accepted

## Context

To ensure a clear understanding of the system architecture across the Godzilla DevOps team, we need a lightweight and collaborative way to visualize the architecture, particularly in the context of CI/CD workflows and SIL/HIL testing.

GitLab supports automatic rendering of diagrams written in either PlantUML, Mermaid.js or any Kroki supported syntax (requires access to running Kroki service) within Markdown files. PlantUML renders C4 diagrams ok, but Mermaid.js is also supported for C4 syntax though they does not look as good (overlapping text and lines).

## Decision

The C4Model SHALL be used for architectural modeling, and diagrams will be created using PlantUML, a textual diagramming tool, embedded in Markdown. These diagrams will be displayed and rendered directly in GitLab, facilitating easy updates, readability and collaboration.

## Consequences

### Positive

- C4Model provides a simple, clear, and structured approach to documenting architecture.
- PlantUML diagrams are easy to maintain and can be embedded in GitLab, enabling inline rendering and version control.
- Text-based diagrams are more maintainable and accessible than graphical tools.
- Diagrams are stored as code in repo.

### Negative

- PlantUML's diagramming capabilities are more limited compared to some dedicated tools.
- Team members may require initial training on how to use the C4Model and PlantUML effectively.

## References

- [C4 Model](https://c4model.com/)
- [PlantUML](https://plantuml.com/)
- [C4-PlantUML](https://github.com/plantuml-stdlib/C4-PlantUML)
- [GitLab support for PlantUML](https://docs.gitlab.com/ee/user/markdown.html#plantuml)
- [GitLab handbook Using PlantUML](https://handbook.gitlab.com/docs/markdown-guide/#plantuml)
- [Mermaid.js](https://mermaid.js.org/)
- [C4 Syntax Mermaid.js](https://mermaid.js.org/syntax/c4.html)
