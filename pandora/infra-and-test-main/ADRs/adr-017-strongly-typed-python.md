# ADR 017: Strong typing in Python and Pyright

## Status

Accepted

## Context

We aim to improve code readability and maintainability by leveraging Python's type hinting capabilities.

## Decision

Python projects SHALL use Pyright as type checking tool and adopt strong typing conventions. Existing projects will gradually transition to this standard over time, ensuring backward compatibility during the migration phase.

## Consequences

### Positive

- Enhanced clarity in function signatures.
- Easier debugging due to early detection of type-related issues.
- Improved tool support for refactoring and static analysis.

### Negative

- May require fixes to existing codebase to conform with the new standard.
- Increased development overhead as developers must define types explicitly.
- Potential performance impact on runtime if not optimized properly.

## References

- [Pyright](https://github.com/microsoft/pyright)
- [Pyright compared to Mypy](https://github.com/microsoft/pyright/blob/main/docs/mypy-comparison.md)
- [Pyre](https://pyre-check.org/)
- [Mypy](http://www.mypy-lang.org/)
- [PEP 484 -- Type Hints](https://www.python.org/dev/peps/pep-0484/)
- [PEP 526 -- Syntax for Variable Annotations](https://www.python.org/dev/peps/pep-0526/)
- [PEP 585 -- Type Hinting Generics In Standard Collections](https://www.python.org/dev/peps/pep-0585/)
- [PEP 593 -- Flexible function and variable annotations](https://www.python.org/dev/peps/pep-0593/)
- [PEP 613 -- Explicit Type Aliases](https://www.python.org/dev/peps/pep-0613/)
- [PEP 647 -- User-Defined Type Guards](https://www.python.org/dev/peps/pep-0647/)
