# import logging
import re
from enum import Enum

import semver
from git import Commit, Repo
from gitlab.v4.objects import Project

from tagger import logger
from tagger.git_helper import (
    get_commits_from_merge_commit,
    get_current_semver_tag,
    get_last_merged_commits,
    get_merge_commits_between,
)
from tagger.gitlab_helper import get_merge_request_commits

TYPE_MINOR = {"feat"}
TYPE_PATCH = {"fix", "perf"}


class Bump(Enum):
    PRE_RELEASE = 1
    BUILD = 2
    PATCH = 3
    MINOR = 4
    MAJOR = 5


def analyze_merge_commit(repo: Repo, commit_sha: str, pre_release: bool) -> tuple[str, str, str]:
    """Analyze a merge commit and return recommended next version and type of version bump.

    Args:
        repo (Repo): The repository object.
        commit_sha (str): The commit SHA to analyze.
        pre_release (bool): If True, bump pre-release version.

    Returns:
        tuple[str, str, str]: Version, type of bump and type of change.
    """
    # Get the commit object from the input commit SHA
    user_commit = repo.commit(commit_sha)

    commits = get_last_merged_commits(repo, user_commit)
    bump_name, bump_type = get_bump_operation(commits, pre_release)

    current_version = get_current_semver_tag(repo, commit_sha, pre_release)

    if current_version:
        next_version, bump_name = bump_semver_version(current_version, bump_name)
    else:
        next_version = ""

    logger.debug(f"Version: {next_version}; Bump: {bump_name}")

    return next_version, bump_name, bump_type


def analyze_multiple_merge_commits(
    repo: Repo, new_commit_sha: str, old_commit_sha: str, pre_release: bool
) -> tuple[str, str, str]:
    """Analyze all merge commits between two commits and return recommended next version
    and type of version bump based on the content of the total set of commit messages.

    Args:
        repo (Repo): The repository object.
        new_commit_sha (str): The newest commit SHA.
        old_commit_sha (str): The oldest commit SHA.
        pre_release (bool): If True, bump pre-release version.

    Returns:
        tuple[str, str, str]: Version, type of bump and type of change.
    """
    newest_version = get_current_semver_tag(repo, new_commit_sha, pre_release)

    merge_commits = get_merge_commits_between(repo, new_commit_sha, old_commit_sha)

    if pre_release:
        highest_bump = Bump.PRE_RELEASE
    else:
        highest_bump = Bump.PATCH

    highest_version = ""
    highest_bump_type = ""

    for merge_commit in merge_commits:
        commits = get_commits_from_merge_commit(repo, merge_commit)
        bump_name, bump_type = get_bump_operation(commits, pre_release)

        if not bump_name:
            continue

        if newest_version:
            next_version, bump_name = bump_semver_version(newest_version, bump_name)
        else:
            next_version = ""

        logger.debug(f"Version: {next_version}; Bump: {bump_name} for SHA: {merge_commit.hexsha}")

        bump_enum = Bump[bump_name.upper()]

        if bump_enum.value >= highest_bump.value:
            highest_bump = bump_enum
            highest_version = next_version
            highest_bump_type = bump_type

    return highest_version, highest_bump.name if highest_version else "", highest_bump_type


def analyze_merge_request(
    repo: Repo, project: Project, mr_iid: str, commit_sha: str, pre_release: bool
) -> tuple[str, str, str]:
    """Analyze merge request and return recommended next version and type of version bump.

    Args:
        repo (Repo): The repository object.
        project (Project): The project object.
        mr_iid (str): The project-level IID (internal ID) of the merge request.
        commit_sha (str): The commit SHA to analyze.
        pre_release (bool): If True, bump pre-release version.

    Returns:
        tuple[str, str, str]: The next version, type of bump and type of change.
    """
    mr_commits = get_merge_request_commits(project=project, mr_iid=mr_iid)
    bump_name, bump_type = get_bump_operation(
        [repo.commit(commit.id) for commit in mr_commits],
        pre_release,
    )

    current_version = get_current_semver_tag(repo, commit_sha, pre_release)

    if current_version:
        next_version, bump_name = bump_semver_version(current_version, bump_name)
    else:
        next_version = ""

    logger.debug(f"Version: {next_version}; Bump: {bump_name}")

    return next_version, bump_name, bump_type


def get_bump_operation(commits: list[Commit], pre_release: bool) -> tuple[str, str]:
    """Get type of version bump based on commit summary and trailer
    for one or more commits in a merge.

    Args:
        commits (list[Commit]): List of commit objects.
        pre_release (bool): If True, bump pre-release version instead of any other version.
                            Adheres to the same bump criteria, but Will override other bump types.

    Returns:
        tuple[str, str]: Recommended type and version bump operation for a set of commits.
    """
    found_types = []
    bump_name = ""
    bump_type = ""

    # Determine the type of bump
    for commit in commits:
        breaking_change = False
        logger.debug(f"Inspect commit: {commit.hexsha}")
        change_type, breaking_change = get_type_and_severity(str(commit.summary), commit.trailers_dict)
        logger.debug(f"Found type: {change_type}, and breaking change: {breaking_change}")

        if breaking_change:
            bump_name = Bump.MAJOR.name
            bump_type = change_type if change_type.endswith("!") else f"{change_type}!"
            break

        found_types.append(change_type)
    else:  # If no breaking change
        logger.debug(
            f"Check found types: {found_types}",
        )
        for commit_type in found_types:
            if commit_type in TYPE_MINOR:
                bump_name = Bump.MINOR.name
                bump_type = commit_type
                break

            if commit_type in TYPE_PATCH:
                bump_name = Bump.PATCH.name
                bump_type = commit_type

    if pre_release and bump_name in [Bump.MAJOR.name, Bump.MINOR.name, Bump.PATCH.name]:
        logger.debug(f"Override bump type {bump_name} due to pre-release")
        bump_name = Bump.PRE_RELEASE.name

    logger.debug(f"Found type of bump: {bump_name}, and type of change: {bump_type}")

    return bump_name, bump_type


def bump_semver_version(previous_version: str, bump_name: str) -> tuple[str, str]:
    """Bump the version based on the type of change.

    Args:
        previous_version (str): Previous version.
        bump_name (str): Type of bump, e.i., MAJOR, MINOR or PATCH.

    Returns:
        tuple[str, str]: The next version and bump type
    """
    # Increment the version based on the bump type
    version = semver.Version.parse(previous_version)

    if bump_name == Bump.MAJOR.name and version.major != 0:
        version = version.bump_major()
    elif bump_name == Bump.MAJOR.name and version.major == 0:
        logger.info("Skip MAJOR version bump due to initial development version (0.y.z) in use!")
        version = version.bump_minor()
        bump_name = Bump.MINOR.name
    elif bump_name == Bump.MINOR.name:
        version = version.bump_minor()
    elif bump_name == Bump.PATCH.name:
        version = version.bump_patch()
    elif bump_name == Bump.BUILD.name:
        version = version.bump_build()
    elif bump_name == Bump.PRE_RELEASE.name:
        version = version.bump_prerelease("")

    return str(version), bump_name


def get_type_and_severity(summary: str, trailers: dict[str, list[str]]) -> tuple[str, bool]:
    """Analyze commit summary and trailers to identify the type of change,
    and if the commit introduces a breaking change.

    Args:
        summary (str): Commit summary
        trailers (dict[str, list[str]]): Commit trailers

    Returns:
        tuple[str, bool]: Type of change and True if breaking change, else False.
    """

    re_summary = r"""
        (?P<type>[^\(!:]+)  # Capture the "type" part, which can be any character(s) except '(', '!', and ':'
        (?:\([^\)]+\))?     # Non-capturing group for the "scope" (optional)
                            # Matches '(' followed by any character(s) except ')' and ending with ')'
        (?P<breaking>!)?    # Capture the "breaking" part (optional)
                            # This matches and captures an exclamation mark '!', if present
    """

    regex = re.compile(re_summary, flags=re.VERBOSE)
    change_type = ""

    match = regex.match(summary.strip())

    # Check if the commit "title" has the indicator(!) for breaking change
    logger.debug(f"Check commit summary: {summary}")
    if match:
        change_type = match.group("type")
        breaking = match.group("breaking")

        if breaking:
            logger.debug(f"Breaking change, found type with exclamation mark: {change_type}")
            return change_type, True

    # Check for a breaking change trailer
    logger.debug(f"Check commit trailer(s): {trailers}")
    for key in trailers:
        if re.match("BREAKING-CHANGE", key, re.IGNORECASE):
            logger.debug(f"Breaking change, found breaking change trailer: {key}")
            return change_type, True

    return change_type, False
