from typing import TypedDict

import semver
from git import Commit, Repo

from tagger import logger

SECONDS_IN_24_HOURS = 86400
STREAM_COMMITS_DISPLAY_LIMIT = 3
LARGE_MERGE_COMMIT_THRESHOLD = 20


class CommitAnalysisException(Exception):
    """Custom exception for errors during commit analysis."""


def get_last_merged_commits(repo: Repo, user_commit: Commit) -> list[Commit]:
    """Returns all commits associated with the last merge commit.

    Args:
        repo (Repo): The repository object.
        user_commit (Commit): The commit object to analyze

    Returns:
        list[Commit]: A list of commit objects.
    """

    # Check if the user commit is the last merge commit
    last_merge_commit = next(repo.iter_commits(max_count=1, merges=True))
    if last_merge_commit != user_commit:
        raise CommitAnalysisException(f"{user_commit.hexsha} is a not a merge commit or not the last merge commit!")

    commits = get_commits_from_merge_commit(repo, user_commit, enforce_ancestry=False)

    return commits


def _log_merge_commit_info(user_commit: Commit, first_parent: Commit, second_parent: Commit) -> None:
    """Logs information about the merge commit and its parents."""
    logger.info("╔══════════════════════════════════════════════════════════════════╗")
    logger.info("║                      MERGE COMMIT ANALYSIS                       ║")
    logger.info("╚══════════════════════════════════════════════════════════════════╝")
    logger.info("Analyzing merge commit: {}", user_commit.hexsha)
    logger.info("Merge commit message: {}", user_commit.message.splitlines()[0])
    logger.info("Merge date: {}", user_commit.authored_datetime.strftime("%Y-%m-%d %H:%M:%S"))
    logger.debug("First parent: {} ({})", first_parent.hexsha, first_parent.message.splitlines()[0])
    logger.debug("Second parent: {} ({})", second_parent.hexsha, second_parent.message.splitlines()[0])


def _get_commits_between(repo: Repo, first_parent: Commit, second_parent: Commit) -> list[Commit]:
    """Returns commits reachable from second_parent but not from first_parent."""
    return list(repo.iter_commits(f"{first_parent.hexsha}..{second_parent.hexsha}"))


class CommitTypes(TypedDict):
    """TypedDict for commit types."""

    feature: list[Commit]
    fix: list[Commit]
    merge: list[Commit]
    other: list[Commit]


def _group_commits_by_type(commits: list[Commit]) -> CommitTypes:
    """Groups commits by conventional commit types."""
    feature_commits, fix_commits, merge_commits, other_commits = [], [], [], []
    for commit in commits:
        msg = str(commit.message).splitlines()[0]
        if len(commit.parents) > 1:
            merge_commits.append(commit)
        elif msg.startswith("feat"):
            feature_commits.append(commit)
        elif msg.startswith("fix"):
            fix_commits.append(commit)
        else:
            other_commits.append(commit)
    return CommitTypes(feature=feature_commits, fix=fix_commits, merge=merge_commits, other=other_commits)


def _get_authors(commits: list[Commit]) -> set[str | None]:
    """Returns a set of unique author emails from the commits."""
    return {commit.author.email for commit in commits}


def _find_similar_commits(commits: list[Commit]) -> list[tuple[Commit, Commit]]:
    """Finds pairs of commits with the same message within 24 hours of each other."""
    similar_commits = []
    for i, commit1 in enumerate(commits):
        for commit2 in commits[i + 1 :]:
            msg1 = str(commit1.message).splitlines()[0]
            msg2 = str(commit2.message).splitlines()[0]
            if msg1 == msg2:
                time_diff = abs((commit1.authored_datetime - commit2.authored_datetime).total_seconds())
                if time_diff < SECONDS_IN_24_HOURS:  # 24 hours in seconds
                    similar_commits.append((commit1, commit2))
    return similar_commits


def _identify_streams(commits: list[Commit]) -> dict[str, list[Commit]]:
    """Identifies development streams based on commit messages."""
    streams = {}
    for commit in commits:
        msg = str(commit.message).splitlines()[0]
        prefix = msg.split(":", maxsplit=1)[0] if ":" in msg else msg.split()[0]
        if prefix not in streams:
            streams[prefix] = []
        streams[prefix].append(commit)
    return streams


class CommitStats(TypedDict):
    """TypedDict for commit statistics."""

    total: int
    authors: int
    features: int
    fixes: int
    merges: int
    other: int


def _log_commit_statistics(stats: CommitStats) -> None:
    """Logs commit statistics."""
    logger.info("\nCommit Statistics:")
    logger.info("  Total:     {} commits by {} authors", stats["total"], stats["authors"])
    logger.info("  ├─ Features: {} commits", stats["features"])
    logger.info("  ├─ Fixes:    {} commits", stats["fixes"])
    logger.info("  ├─ Merges:   {} commits", stats["merges"])
    logger.info("  └─ Other:    {} commits", stats["other"])


def _log_workflow_analysis(
    commits: list[Commit],
    is_traditional_merge: bool,
    merge_commits: list[Commit],
    similar_commits: list[tuple[Commit, Commit]],
) -> None:
    """Logs workflow analysis."""
    if commits:
        logger.info("\nWorkflow Analysis:")
        if not is_traditional_merge:
            logger.info("  • Parallel development detected: branches diverged from common ancestor")
        if len(merge_commits) > 0:
            logger.info("  • Internal merges detected: {} merge commits within branch", len(merge_commits))
            logger.info("    Consider using rebase to maintain a cleaner history")
        if similar_commits:
            logger.info("  • Similar commits detected: {} pairs of similar commits", len(similar_commits))
            logger.info("    This may indicate parallel development of the same features")
        if len(commits) > LARGE_MERGE_COMMIT_THRESHOLD:
            logger.info("  • Large merge detected: {} commits", len(commits))
            logger.info("    Consider squashing commits or smaller, more frequent merges for easier review")
            logger.info("    Consider squashing commits or smaller, more frequent merges for easier review")


def _log_streams(streams: dict[str, list[Commit]]) -> None:
    """Helper to log identified development streams."""
    logger.debug("Development streams identified:")
    for prefix, stream_commits in streams.items():
        logger.debug("- {}: {} commits", prefix, len(stream_commits))
        for i, commit in enumerate(stream_commits):
            if i < STREAM_COMMITS_DISPLAY_LIMIT or i >= len(stream_commits) - STREAM_COMMITS_DISPLAY_LIMIT:
                logger.debug(
                    "  {}: {} ({})",
                    commit.hexsha[:8],
                    commit.message.splitlines()[0],
                    commit.authored_datetime.strftime("%Y-%m-%d %H:%M:%S"),
                )
            elif i == STREAM_COMMITS_DISPLAY_LIMIT and len(stream_commits) > 2 * STREAM_COMMITS_DISPLAY_LIMIT:
                logger.debug("  ... {} more commits ...", len(stream_commits) - 2 * STREAM_COMMITS_DISPLAY_LIMIT)
            logger.trace(
                "  Commit: {} - {} ({})",
                commit.hexsha,
                commit.message.splitlines()[0],
                commit.authored_datetime.strftime("%Y-%m-%d %H:%M:%S"),
            )


def _log_trace_commits(commits: list[Commit]) -> None:
    """Helper to log all commits in chronological order at TRACE level."""
    logger.trace("All commits in chronological order:")
    for commit in commits:
        logger.trace(
            "{} - {}:\n{}",
            commit.hexsha[:8],
            commit.authored_datetime.strftime("%Y-%m-%d %H:%M:%S"),
            commit.message.strip(),
        )


def _perform_and_log_commit_details(commits: list[Commit], is_traditional_merge: bool) -> None:
    """
    Analyzes a list of commits and logs detailed statistics, workflow insights,
    development streams, and trace information.
    """
    grouped_commits = _group_commits_by_type(commits)
    authors = _get_authors(commits)
    similar_commits = _find_similar_commits(commits)

    stats = CommitStats(
        total=len(commits),
        authors=len(authors),
        features=len(grouped_commits["feature"]),
        fixes=len(grouped_commits["fix"]),
        merges=len(grouped_commits["merge"]),
        other=len(grouped_commits["other"]),
    )
    _log_commit_statistics(stats)

    # For workflow analysis, pass the actual list of internal merge commits
    _log_workflow_analysis(commits, is_traditional_merge, grouped_commits["merge"], similar_commits)

    streams = _identify_streams(commits)
    _log_streams(streams)
    _log_trace_commits(commits)


def get_commits_from_merge_commit(repo: Repo, user_commit: Commit, enforce_ancestry: bool = False) -> list[Commit]:
    """Returns all commits associated with a merge commit.

    Args:
        repo (Repo): The repository object.
        user_commit (Commit): The commit object to analyze
        enforce_ancestry (bool): If True, enforces that first parent must be
            ancestor of second parent (old behavior). Default False.

    Returns:
        list[Commit]: A list of commit objects, sorted chronologically.

    Raises:
        CommitAnalysisException: If the commit is not a merge commit, or if
            ancestry check fails (when enforce_ancestry is True), or if no
            common ancestor can be found between the merge parents.
    """

    if not len(user_commit.parents) > 1:
        raise CommitAnalysisException(f"{user_commit.hexsha} is not a merge commit!")

    first_parent = user_commit.parents[0]
    second_parent = user_commit.parents[1]

    _log_merge_commit_info(user_commit, first_parent, second_parent)

    is_traditional_merge = is_ancestor(repo=repo, ancestor_commit=first_parent, descendant_commit=second_parent)

    if is_traditional_merge:
        logger.info("Merge type: Traditional (first parent is ancestor of second)")
    else:
        logger.info("Merge type: Parallel Development (non-traditional)")

    logger.debug("Is traditional merge (first parent is ancestor of second): {}", is_traditional_merge)

    if enforce_ancestry and not is_traditional_merge:
        logger.warning("Ancestry check failed: first parent is not an ancestor of second parent")
        raise CommitAnalysisException(
            f"{first_parent.hexsha} is not ancestor to {second_parent.hexsha}, commit needs to be rebased!"
        )

    merge_base = repo.merge_base(first_parent, second_parent)
    if not merge_base:
        logger.error("No common ancestor found between merge parents")
        raise CommitAnalysisException(
            f"No common ancestor found between merge parents:\n"
            f"First parent: {first_parent.hexsha} ({first_parent.message.splitlines()[0]})\n"
            f"Second parent: {second_parent.hexsha} ({second_parent.message.splitlines()[0]})"
        )

    common_ancestor = merge_base[0]
    logger.debug("Common ancestor of parents: {} ({})", common_ancestor.hexsha, common_ancestor.message.splitlines()[0])

    commits = _get_commits_between(repo, first_parent, second_parent)

    if not commits:
        logger.warning(
            "No commits found between {} and {} - this might indicate an empty merge",
            first_parent.hexsha,
            second_parent.hexsha,
        )
        return []

    commits.sort(key=lambda c: c.authored_datetime)

    logger.info("\nSummary:")
    logger.info("  Found {} commits between {} and {}", len(commits), first_parent.hexsha[:8], second_parent.hexsha[:8])

    # Perform detailed analysis and logging on the found commits
    _perform_and_log_commit_details(commits, is_traditional_merge)

    return commits


def is_ancestor(repo: Repo, ancestor_commit: Commit, descendant_commit: Commit) -> bool:
    """Checks if ancestor_commit is an ancestor of descendant_commit.

    Args:
        repo (Repo): The repository object.
        ancestor_commit (Commit): The commit object of the potential ancestor commit.
        descendant_commit (Commit): The commit object of the potential descendant commit.

    Returns:
        bool: True if ancestor_commit is an ancestor of descendant_commit, False otherwise.
    """
    # Traverse the descendant's history to see if the ancestor is in it
    for commit in repo.iter_commits(descendant_commit):
        if commit == ancestor_commit:
            return True

    return False


def pre_release_sort_key(version_str: str) -> tuple[int, int, int, int]:
    """Custom sort key for SemVer strings, primarily for integer pre-releases (e.g., '1.2.3-1')."""
    version = semver.Version.parse(version_str)
    prerelease_sort_component = 0

    logger.trace(f"Parsing '{version_str}': prerelease='{version.prerelease}'")

    if version.prerelease:
        if isinstance(version.prerelease, int):
            prerelease_sort_component = version.prerelease
            logger.trace(f"Int prerelease: {prerelease_sort_component}")
        elif isinstance(version.prerelease, str):
            if version.prerelease.isdigit():
                try:
                    prerelease_sort_component = int(version.prerelease)
                    logger.trace(f"Str->int prerelease: {prerelease_sort_component}")
                except ValueError:
                    logger.warning(f"Failed to convert '{version.prerelease}' to int")
            else:
                logger.trace(f"Non-numeric prerelease: '{version.prerelease}'")
        else:
            logger.trace(f"Unsupported prerelease type: {type(version.prerelease).__name__}")

    key_tuple = (version.major, version.minor, version.patch, prerelease_sort_component)
    logger.trace(f"'{version_str}' -> {key_tuple}")
    return key_tuple


def get_current_semver_tag(repo: Repo, commit_sha: str, pre_release: bool) -> str:
    """Get the current version.

    Args:
        repo (Repo): The repository object.
        commit_sha (str): The ref to use to find applicable tags.
        pre_release (bool): If True, apply custom version sorting.


    Returns:
        str: Semver version.
    """
    visible_tags = []
    commits = list(repo.iter_commits(commit_sha))

    # Collect tags that point to any of these commits
    for tag in repo.tags:
        if tag.commit in commits:
            visible_tags.append(tag.name)

    logger.debug("Visible tags: {}", visible_tags)

    # Filter tags that are valid SemVer
    semver_tags = []
    for tag in visible_tags:
        # Get the tag name and check if it's a valid SemVer
        if semver.Version.is_valid(tag):
            semver_tags.append(tag)

    logger.debug(f"SemVer tags before sort ({len(semver_tags)}): {semver_tags}")

    # Sort the SemVer tags
    # If pre_release is True, we deviate from "proper" version sorting and use the custom sort key to sort the tags
    if pre_release:
        logger.debug("Sorting with higher precedence for pre-release versions using pre_release_sort_key")
        semver_tags.sort(key=pre_release_sort_key)
    else:
        logger.debug("Sorting with standard semver.Version.parse key")
        semver_tags.sort(key=semver.Version.parse)

    current_version = semver_tags[-1] if semver_tags else ""
    logger.debug(f"SemVer tags after sort ({len(semver_tags)}): {semver_tags}")
    logger.info("Found current version: {}", current_version)

    return current_version


def get_merge_commits_between(repo: Repo, new_commit_sha: str, old_commit_sha: str) -> list[Commit]:
    """Finds all merge commits between two commits (inclusive of new_commit_sha if it is a merge commit).

    Args:
        repo (Repo): The repository object.
        old_commit_sha (str): The SHA of the older commit.
        new_commit_sha (str): The SHA of the newer commit.

    Returns:
        list[Commit]: A list of merge commit objects.
    """
    merge_commits = []

    # Get all commits between old_commit_sha (exclusive) and new_commit_sha (inclusive)
    commits = list(repo.iter_commits(f"{old_commit_sha}..{new_commit_sha}"))

    for commit in commits:
        if len(commit.parents) > 1:  # Merge commits have more than one parent
            merge_commits.append(commit)

    logger.info("Found {} merge commits", len(merge_commits))
    for commit in merge_commits:
        logger.debug("- {}: {}", commit.hexsha[:8], commit.message.splitlines()[0])
    return merge_commits
