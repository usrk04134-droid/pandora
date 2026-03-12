# Tagger (Your friendly neighborhood semver tagging tool)

## Description

The purpose of `Tagger` is to analyze a commit and decide if the project semver
version should be incremented or not.\
The commit must be either a merge commit or a commit in a merge request.

The analysis is based on the commit messages extracted from the commits that is
part of the merge or merge request, and the commit message is assumed to comply
with the conventional commit format.\
See [Adaptio wiki - Git commit message format](https://gitlab.com/groups/esab/abw/-/wikis/Infrastructure-&-Test/Git-commit-message-format)

Based on the `type` in the subject, `Tagger` will decide if the `minor` or
`patch` version should be incremented.

`type` followed by an `!`, and/or a `BREAKING-CHANGE:` trailer indicates a
breaking change, and that the `major` version should be incremented.

**Example:**

```bash
feat!: Some breaking change

- Some body text

BREAKING-CHANGE: Major interface changes
Issues: ADT-XYZ
```

A recommended new version is calculated based on other semver version tags found
in the project.\
`Tagger` will find the latest semver version tag that is visible from the given
commit and bump that version based on the result from the commit message analysis.

If a new version tag is needed, `Tagger` will also be able to create that tag
for you.

> [!note]
> If the `--pre-release` option is used, only the pre-release version will be bumped, regardless if the change is a `MAJOR`, `MINOR` or `PATCH`.

## Table of Contents

- [Tagger (Your friendly neighborhood semver tagging tool)](#tagger-your-friendly-neighborhood-semver-tagging-tool)
   - [Description](#description)
   - [Table of Contents](#table-of-contents)
   - [Usage](#usage)
   - [Development](#development)

## Usage

Tagger is intended for use in a CI context and depends on the following
environment variables to be set:

```bash
CI_PROJECT_ID             # Gitlab predefined pipeline variable
CI_SERVER_URL             # Gitlab predefined pipeline variable
SERVICE_ACCOUNT_PAT       # Service account token

# Only required if option --merge-request is used
CI_MERGE_REQUEST_IID  # Gitlab predefined pipeline variable that is only available in merge request pipelines.
```

The command `analyze` is used to analyze a given commit SHA and to understand
what type of version bump is needed and what the new version should be.

```bash
Usage: tagger analyze [OPTIONS] COMMAND [ARGS]...

  Analyze merge commits, or merge requests.

Options:
  -h, --help  Show this message and exit.

Commands:
  merge-commit            Analyze a single merge commit.
  merge-request           Analyze a merge request.
  multiple-merge-commits  Analyze all merge commits between two commits.
```

It is possible to get the result as a `tagger.env` file

```bash
['SEMVER_VERSION=1.0.0', 'SEMVER_BUMP=MAJOR']
```

The command `add tag` is used to create a tag in Gitlab for a given commit.

```bash
Usage: tagger add tag [OPTIONS] COMMIT_SHA NAME MESSAGE

Options:
  -h, --help  Show this message and exit.
```

The command `add approval` is used to add an approval rule to a merge request.

```bash
Usage: tagger add approval [OPTIONS] MR_IID NAME [USERNAMES]...

Options:
  -h, --help  Show this message and exit.
```

The command `add note` is used to add a note to a merge request.

```bash
Usage: tagger add note [OPTIONS] MR_IID MESSAGE

Options:
  -h, --help  Show this message and exit.
```

The command `calculate version` is used to calculate the next version given type of version bump.

```bash
Usage: tagger calculate version [OPTIONS] CURRENT_VERSION BUMP_NAME

Options:
  --dotenv    Output to tagger.env
  -h, --help  Show this message and exit.
```

## Development

Tagger is written as a package and for development purpose it is recommended to
install in editable mode, e.g., `pip install -e` in a virtual environment.
