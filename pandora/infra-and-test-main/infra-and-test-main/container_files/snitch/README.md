
# Snitch – TestRail API Python Library

**Snitch** is a Python library and CLI tool to interact with the [TestRail API](https://www.gurock.com/testrail/docs/api/), supporting test project management, execution, and results tracking through a clean and typed Python interface.

---

## 🚀 Features

- Full support for core TestRail entities (Projects, Suites, Sections, Cases, Runs, Results)
- Object-oriented, typed Python wrapper for better DX
- CLI-ready with logging and structured exception handling
- Environment-variable based configuration
- Integration-tested with pytest

---

## 📦 Installation

Requires **Python 3.12+**

```bash
git clone https://github.com/your-org/snitch.git
cd snitch
pip install -e .
```

To install development dependencies:

```bash
pip install -e .[dev]
```

---

## ⚡ Quick Start

```python
from snitch.api_client import TestRailAPIClient
from snitch.projects import Projects

client = TestRailAPIClient(
    base_url="https://your-instance.testrail.io",
    username="user@example.com",
    api_key="your-api-key"
)

projects = Projects(client)
print(projects.get_projects())
```

---

## ⚙️ Configuration

You can export credentials as environment variables:

```bash
export TESTRAIL_URL="https://your-instance.testrail.io"
export TESTRAIL_USERNAME="user@example.com"
export TESTRAIL_API_KEY="your-api-key"
```

---

## 🧪 Running Tests

### Integration Tests

Integration tests are located in `tests/integration` and expect a live TestRail instance.

1. Set up `.env` or export these variables:

   ```bash
   export TESTRAIL_URL="..."
   export TESTRAIL_USERNAME="..."
   export TESTRAIL_API_KEY="..."
   export TESTRAIL_PROJECT_ID="..."  # required for some integration tests
   ```

2. Run tests:

   ```bash
   pytest tests/integration
   ```

3. Optional: generate coverage report:

   ```bash
   pytest --cov=snitch --cov-report=term-missing
   ```

---

## 🧱 Project Structure

```text
snitch/
├── src/snitch/
│   ├── api_client.py      # Core API client with GET/POST logic
│   ├── projects.py        # Projects wrapper
│   ├── suites.py          # Suites wrapper
│   ├── cases.py           # Cases wrapper
│   ├── runs.py            # Runs wrapper
│   ├── results.py         # Results wrapper
│   └── sections.py        # Sections wrapper
├── tests/
│   └── integration/       # Integration tests using pytest
├── pyproject.toml         # Project and dependency metadata
└── README.md              # This file
```

---

## 🛠️ Contributing

We welcome contributions! Here's how to get started:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Write unit or integration tests for your feature
4. Follow naming conventions for wrapper methods:
   - `get_entities`, `get_entity`
   - `add_entity`, `update_entity`, `delete_entity`
5. Run tests with `pytest`
6. Open a pull request with a clear description

---

## 📄 License

All belongs to ESAB Automation! Do not copy, do not distribute, do not use.

---

## 🙏 Acknowledgments

- [Gurock TestRail API](https://www.gurock.com/testrail/docs/api/)
- Inspired by clean API wrapper patterns in Python open-source projects
