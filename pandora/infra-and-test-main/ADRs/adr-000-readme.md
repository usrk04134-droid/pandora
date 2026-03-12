# ADR 000: README

# WHAT

Architectural Decision Records (ADRs) is a document that captures an important architectural decision made along with its context and consequences.

# WHY

To simplify knowledge sharing, keep important information up-to-date, keep documentation close to the source, reduce the number of (incorrect) assumptions taken by developers, simplify onboarding, increase alignment between developers, visualize dependencies, reduce the number of unknown unknowns and make architectural documentation easily digestible.

# WHEN

Whenever any decision is taken that affects the development and/or system in a way that makes a future change a significant effort. E.g., decisions that affect structure, dependencies, interfaces, system characteristics, technologies or flexibility.

Examples:

- Programming language of choice
- Principles followed
- Technologies used
- Rationale of the system
- Cloud provider
- Messaging protocol
- Testing framework
- System abstraction
- Project structure

# HOW

- The filename SHALL be in the form `adr-<id>-<short-description>.md`.
- The filename SHALL contain a unique, three digit, sequential, monotonically increasing number (`NNN` id). _This helps with identification and references._
- The filename SHALL be written as a present tense imperative verb phrase. _This helps readability and matches our commit message format._
- The filename SHALL be written using only lowercase characters and dashes. _This is a balance of readability and system usability._
- The extension SHALL be markdown. _This ensures easy formatting and rendering._
- The template `adr-000-template.md` SHALL be followed. _This ensures consistency and alignment._
- RFC2119 key words SHALL be used. _This helps with readability and is clearly defined._
- Rejected, reversed or superseded ADRs SHALL be kept and marked as such. _This ensures consistency and clarity._
- Timestamps SHALL NOT be written in the files. Git handles this for us. _This ensures consistent information and reduces manual overhead._
- The status SHALL be one of `Proposed`, `Accepted`, `Rejected`, `Reversed` or `Superseded by <NNN>`. _This helps with readability, searchability and filtering._
- Initial state of an ADR SHALL be `Proposed` when delivered to main. _This provides a clear history and allows for discussion._
- Superseded ADRs SHALL specify which ADR superseds it. _This helps with traceability._
- All updates of status SHALL be done as individual merge requests without other changes to the ADR or other files. _This provides a clear history and allows for discussion._

# References

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions.html)
- [Homepage of the ADR GitHub organization](https://adr.github.io/)
- [RFC2119: Key words to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119)
