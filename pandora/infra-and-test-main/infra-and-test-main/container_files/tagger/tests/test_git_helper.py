import random
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

import pytest
from tagger.git_helper import (
    CommitAnalysisException,
    get_commits_from_merge_commit,
    get_current_semver_tag,
    get_last_merged_commits,
    get_merge_commits_between,
    is_ancestor,
    pre_release_sort_key,
)


# Dummy classes for commits and tags.
class DummyCommit:
    def __init__(self, sha):
        self.sha = sha

    def __eq__(self, other):
        if isinstance(other, DummyCommit):
            return self.sha == other.sha
        return False

    def __hash__(self):
        return hash(self.sha)


class DummyTag:
    def __init__(self, name, commit):
        self.name = name
        self.commit = commit


def test_pre_release_sort_key__no_prerelease():
    v_major, v_minor, v_patch, v_prerelase = pre_release_sort_key("0.1.0")
    assert v_major == 0
    assert v_minor == 1
    assert v_patch == 0
    assert v_prerelase == 0


def test_pre_release_sort_key__with_prerelease():
    v_major, v_minor, v_patch, v_prerelase = pre_release_sort_key("0.1.0-1")
    assert v_major == 0
    assert v_minor == 1
    assert v_patch == 0
    assert v_prerelase == 1


def test_pre_release_sort_key__with_prerelease_alpha():
    v_major, v_minor, v_patch, v_prerelase = pre_release_sort_key("0.1.0-alpha")
    assert v_major == 0
    assert v_minor == 1
    assert v_patch == 0
    assert v_prerelase == 0


def test_get_current_semver_tag__no_valid_semver_tags():
    fake_repo = MagicMock()
    commit1 = DummyCommit("abc123")
    tag1 = DummyTag("test", commit1)

    fake_repo.iter_commits.return_value = [commit1]
    fake_repo.tags = [tag1]  # no valid semver tags available

    result = get_current_semver_tag(fake_repo, "abc123", pre_release=False)
    assert result == ""

    commit2 = DummyCommit("abc456")

    fake_repo.iter_commits.return_value = [commit2]
    fake_repo.tags = []  # no tags available

    result = get_current_semver_tag(fake_repo, "abc123", pre_release=False)
    assert result == ""


def test_get_current_semver_tag__valid_tags():
    commit1 = DummyCommit("sha1")
    commit2 = DummyCommit("sha2")
    commit3 = DummyCommit("sha3")

    fake_repo = MagicMock()
    fake_repo.iter_commits.return_value = [commit1, commit2, commit3]

    tag1 = DummyTag("0.1.0", commit1)
    tag2 = DummyTag("0.2.1", commit2)
    tag3 = DummyTag("0.2.1-1", commit3)
    tag_invalid = DummyTag("not-semver", commit3)
    fake_repo.tags = [tag1, tag2, tag3, tag_invalid]

    # When pre_release is False: sorting using semver.Version.parse should treat 0.2.1 as higher than 0.2.1-1
    result = get_current_semver_tag(fake_repo, "sha1", pre_release=False)
    assert result == "0.2.1"

    # When pre_release is True: the custom sort key will treat missing prerelease as 0, so 0.2.1-1 comes after 0.2.1.
    result_pre = get_current_semver_tag(fake_repo, "sha1", pre_release=True)
    assert result_pre == "0.2.1-1"


@patch("tagger.git_helper.Repo")
def test_get_commits_from_merge_commit(mock_repo):
    # Setup mock repo and commit
    repo = mock_repo()
    user_commit = MagicMock()
    parent_commit_1 = MagicMock()
    parent_commit_2 = MagicMock()

    user_commit.parents = [parent_commit_1, parent_commit_2]
    user_commit.hexsha = "mocksha"
    user_commit.message = "Mock merge commit message"
    user_commit.authored_datetime = datetime(2023, 1, 1, 12, 0, 0)

    # Configure parent commits
    parent_commit_1.hexsha = "parent1sha"
    parent_commit_1.message = "Parent 1 commit message"
    parent_commit_2.hexsha = "parent2sha"
    parent_commit_2.message = "Parent 2 commit message"

    # Create mock commits with proper datetime objects for sorting
    mock_commit_1 = MagicMock()
    mock_commit_1.authored_datetime = datetime(2023, 1, 1, 10, 0, 0)
    mock_commit_1.message = "First commit"
    mock_commit_1.hexsha = "commit1sha"
    mock_commit_1.parents = [MagicMock()]  # Single parent (not a merge)
    mock_commit_1.author.email = "dev1@example.com"

    mock_commit_2 = MagicMock()
    mock_commit_2.authored_datetime = datetime(2023, 1, 1, 11, 0, 0)
    mock_commit_2.message = "Second commit"
    mock_commit_2.hexsha = "commit2sha"
    mock_commit_2.parents = [MagicMock()]  # Single parent (not a merge)
    mock_commit_2.author.email = "dev2@example.com"

    mock_commits = [mock_commit_2, mock_commit_1]  # Intentionally out of order

    # Setup repo mocks
    repo.iter_commits.return_value = mock_commits
    repo.merge_base.return_value = [MagicMock()]  # Mock common ancestor

    with (
        patch("tagger.git_helper.is_ancestor", return_value=True),
        patch("tagger.git_helper._get_commits_between", return_value=mock_commits),
    ):
        result = get_commits_from_merge_commit(repo, user_commit)

        # Verify the result is sorted chronologically
        assert len(result) == 2
        assert result[0].authored_datetime < result[1].authored_datetime
        # The commits should be sorted: mock_commit_1 (10:00) then mock_commit_2 (11:00)
        assert result[0] == mock_commit_1
        assert result[1] == mock_commit_2


@patch("tagger.git_helper.Repo")
def test_not_a_merge_commit(mock_repo):
    # Setup mock commit with no parents
    repo = mock_repo()
    user_commit = MagicMock()
    user_commit.parents = []
    user_commit.hexsha = "mocksha"

    with pytest.raises(CommitAnalysisException) as exc_info:
        get_commits_from_merge_commit(repo, user_commit)

    assert str(exc_info.value) == "mocksha is not a merge commit!"


@patch("tagger.git_helper.Repo")
def test_commit_needs_rebase(mock_repo):
    # Setup mock repo and commit
    repo = mock_repo()
    user_commit = MagicMock()
    parent_commit_1 = MagicMock()
    parent_commit_2 = MagicMock()

    user_commit.parents = [parent_commit_1, parent_commit_2]
    user_commit.hexsha = "mocksha"
    user_commit.message = "Mock merge commit message"
    user_commit.authored_datetime = datetime(2023, 1, 1, 12, 0, 0)

    # Configure parent commits properly
    parent_commit_1.hexsha = "parent1sha"
    parent_commit_1.message = "Parent 1 commit message"
    parent_commit_2.hexsha = "parent2sha"
    parent_commit_2.message = "Parent 2 commit message"

    # Mock merge_base to return a common ancestor
    repo.merge_base.return_value = [MagicMock()]

    with (
        patch("tagger.git_helper.is_ancestor", return_value=False),
        patch("tagger.git_helper._get_commits_between", return_value=[]),
    ):
        with pytest.raises(CommitAnalysisException) as exc_info:
            get_commits_from_merge_commit(repo, user_commit, enforce_ancestry=True)

        expected_msg = (
            f"{parent_commit_1.hexsha} is not ancestor to {parent_commit_2.hexsha}, commit needs to be rebased!"
        )
        assert str(exc_info.value) == expected_msg


def test_get_merge_commits_between():
    # Setup mock repo and commits
    repo = MagicMock()
    commit1 = MagicMock()
    commit2 = MagicMock()
    commit3 = MagicMock()

    # Configure the mock commits
    commit1.parents = [MagicMock()]
    commit1.hexsha = "commit1sha"
    commit1.message = "Regular commit"

    commit2.parents = [MagicMock(), MagicMock()]  # Merge commit
    commit2.hexsha = "commit2sha"
    commit2.message = "Merge commit 1"

    commit3.parents = [MagicMock(), MagicMock()]  # Merge commit
    commit3.hexsha = "commit3sha"
    commit3.message = "Merge commit 2"

    # Mock the iter_commits method to return a list of commits
    repo.iter_commits.return_value = [commit1, commit2, commit3]

    result = get_merge_commits_between(repo, "new_sha", "old_sha")

    # Assertions - only merge commits should be returned
    expected_commits = [commit2, commit3]
    assert result == expected_commits
    repo.iter_commits.assert_called_once_with("old_sha..new_sha")


# Additional test cases for pre_release_sort_key
def test_pre_release_sort_key_edge_cases():
    """Test edge cases for pre_release_sort_key function."""

    # Test with numeric string prerelease
    result = pre_release_sort_key("1.0.0-123")
    assert result == (1, 0, 0, 123)

    # Test with non-numeric string prerelease
    result = pre_release_sort_key("1.0.0-beta")
    assert result == (1, 0, 0, 0)

    # Test with complex prerelease
    result = pre_release_sort_key("1.0.0-alpha.1")
    assert result == (1, 0, 0, 0)

    # Test with zero prerelease
    result = pre_release_sort_key("1.0.0-0")
    assert result == (1, 0, 0, 0)


def test_pre_release_sort_key_sorting_behavior():
    """Test that pre_release_sort_key produces correct sorting order."""
    versions = ["1.0.0", "1.0.0-1", "1.0.0-2", "1.0.0-alpha", "1.0.1"]
    sorted_versions = sorted(versions, key=pre_release_sort_key)

    # Should be: 1.0.0, 1.0.0-alpha, 1.0.0-1, 1.0.0-2, 1.0.1
    expected = ["1.0.0", "1.0.0-alpha", "1.0.0-1", "1.0.0-2", "1.0.1"]
    assert sorted_versions == expected


# Additional test cases for get_current_semver_tag
def test_get_current_semver_tag_complex_scenarios():
    """Test complex scenarios for get_current_semver_tag."""

    # Test with mixed valid and invalid tags
    fake_repo = MagicMock()
    commit1 = MagicMock()
    commit2 = MagicMock()
    commit3 = MagicMock()

    fake_repo.iter_commits.return_value = [commit1, commit2, commit3]

    # Mix of valid semver, invalid semver, and edge cases
    tags = [
        DummyTag("v1.0.0", commit1),  # Has 'v' prefix - invalid semver
        DummyTag("1.0.0", commit1),  # Valid
        DummyTag("2.0.0-alpha", commit2),  # Valid with prerelease
        DummyTag("invalid", commit3),  # Invalid
        DummyTag("1.0.0-1", commit1),  # Valid with numeric prerelease
    ]
    fake_repo.tags = tags

    # Test standard sorting
    result = get_current_semver_tag(fake_repo, "commit1", pre_release=False)
    assert result == "2.0.0-alpha"  # Highest version

    # Test prerelease sorting
    result = get_current_semver_tag(fake_repo, "commit1", pre_release=True)
    assert result == "2.0.0-alpha"


def test_get_current_semver_tag_no_commits():
    """Test when no commits are found."""
    fake_repo = MagicMock()
    fake_repo.iter_commits.return_value = []
    fake_repo.tags = []

    result = get_current_semver_tag(fake_repo, "nonexistent", pre_release=False)
    assert result == ""


# Additional test cases for get_commits_from_merge_commit
@patch("tagger.git_helper.Repo")
def test_get_commits_from_merge_commit_no_common_ancestor(mock_repo):
    """Test when no common ancestor is found between parents."""
    repo = mock_repo()
    user_commit = MagicMock()
    parent_commit_1 = MagicMock()
    parent_commit_2 = MagicMock()

    user_commit.parents = [parent_commit_1, parent_commit_2]
    user_commit.hexsha = "mocksha"
    user_commit.message = "Mock merge commit message"
    user_commit.authored_datetime = datetime(2023, 1, 1, 12, 0, 0)

    parent_commit_1.hexsha = "parent1sha"
    parent_commit_1.message = "Parent 1 commit message"
    parent_commit_2.hexsha = "parent2sha"
    parent_commit_2.message = "Parent 2 commit message"

    # Mock merge_base to return empty list (no common ancestor)
    repo.merge_base.return_value = []

    with patch("tagger.git_helper.is_ancestor", return_value=False):
        with pytest.raises(CommitAnalysisException) as exc_info:
            get_commits_from_merge_commit(repo, user_commit)

        assert "No common ancestor found between merge parents" in str(exc_info.value)


@patch("tagger.git_helper.Repo")
def test_get_commits_from_merge_commit_empty_merge(mock_repo):
    """Test when merge commit has no commits between parents (empty merge)."""
    repo = mock_repo()
    user_commit = MagicMock()
    parent_commit_1 = MagicMock()
    parent_commit_2 = MagicMock()

    user_commit.parents = [parent_commit_1, parent_commit_2]
    user_commit.hexsha = "mocksha"
    user_commit.message = "Mock merge commit message"
    user_commit.authored_datetime = datetime(2023, 1, 1, 12, 0, 0)

    parent_commit_1.hexsha = "parent1sha"
    parent_commit_1.message = "Parent 1 commit message"
    parent_commit_2.hexsha = "parent2sha"
    parent_commit_2.message = "Parent 2 commit message"

    repo.merge_base.return_value = [MagicMock()]

    with (
        patch("tagger.git_helper.is_ancestor", return_value=True),
        patch("tagger.git_helper._get_commits_between", return_value=[]),
    ):
        result = get_commits_from_merge_commit(repo, user_commit)
        assert not result


@patch("tagger.git_helper.Repo")
def test_get_commits_from_merge_commit_parallel_development(mock_repo):
    """Test merge commit with parallel development (non-traditional merge)."""
    repo = mock_repo()
    user_commit = MagicMock()
    parent_commit_1 = MagicMock()
    parent_commit_2 = MagicMock()

    user_commit.parents = [parent_commit_1, parent_commit_2]
    user_commit.hexsha = "mocksha"
    user_commit.message = "Mock merge commit message"
    user_commit.authored_datetime = datetime(2023, 1, 1, 12, 0, 0)

    parent_commit_1.hexsha = "parent1sha"
    parent_commit_1.message = "Parent 1 commit message"
    parent_commit_2.hexsha = "parent2sha"
    parent_commit_2.message = "Parent 2 commit message"

    # Create commits with various types for analysis
    feature_commit = MagicMock()
    feature_commit.authored_datetime = datetime(2023, 1, 1, 10, 0, 0)
    feature_commit.message = "feat: add new feature"
    feature_commit.parents = [MagicMock()]
    feature_commit.author.email = "dev1@example.com"
    feature_commit.hexsha = "feat123"

    fix_commit = MagicMock()
    fix_commit.authored_datetime = datetime(2023, 1, 1, 11, 0, 0)
    fix_commit.message = "fix: resolve bug"
    fix_commit.parents = [MagicMock()]
    fix_commit.author.email = "dev2@example.com"
    fix_commit.hexsha = "fix456"

    merge_commit = MagicMock()
    merge_commit.authored_datetime = datetime(2023, 1, 1, 9, 0, 0)
    merge_commit.message = "Merge branch 'feature-x'"
    merge_commit.parents = [MagicMock(), MagicMock()]  # Multiple parents
    merge_commit.author.email = "dev3@example.com"
    merge_commit.hexsha = "merge789"

    mock_commits = [feature_commit, fix_commit, merge_commit]

    repo.merge_base.return_value = [MagicMock()]

    with (
        patch("tagger.git_helper.is_ancestor", return_value=False),  # Parallel development
        patch("tagger.git_helper._get_commits_between", return_value=mock_commits),
    ):
        result = get_commits_from_merge_commit(repo, user_commit)

        # Should be sorted chronologically
        assert len(result) == 3
        assert result[0] == merge_commit  # 9:00
        assert result[1] == feature_commit  # 10:00
        assert result[2] == fix_commit  # 11:00


@patch("tagger.git_helper.Repo")
def test_get_commits_from_merge_commit_single_parent(mock_repo):
    """Test with commit that has only one parent (not a merge)."""
    repo = mock_repo()
    user_commit = MagicMock()
    user_commit.parents = [MagicMock()]  # Only one parent
    user_commit.hexsha = "mocksha"

    with pytest.raises(CommitAnalysisException) as exc_info:
        get_commits_from_merge_commit(repo, user_commit)

    assert "mocksha is not a merge commit!" in str(exc_info.value)


@patch("tagger.git_helper.Repo")
def test_get_commits_from_merge_commit_three_parents(mock_repo):
    """Test merge commit with three parents (octopus merge)."""
    repo = mock_repo()
    user_commit = MagicMock()
    parent1 = MagicMock()
    parent2 = MagicMock()
    parent3 = MagicMock()

    user_commit.parents = [parent1, parent2, parent3]
    user_commit.hexsha = "octopus"
    user_commit.message = "Octopus merge"
    user_commit.authored_datetime = datetime(2023, 1, 1, 12, 0, 0)

    parent1.hexsha = "parent1"
    parent1.message = "Parent 1"
    parent2.hexsha = "parent2"
    parent2.message = "Parent 2"

    repo.merge_base.return_value = [MagicMock()]

    with (
        patch("tagger.git_helper.is_ancestor", return_value=True),
        patch("tagger.git_helper._get_commits_between", return_value=[]),
    ):
        # Should work with octopus merge (uses first two parents)
        result = get_commits_from_merge_commit(repo, user_commit)
        assert not result


# Test cases for is_ancestor function
@patch("tagger.git_helper.Repo")
def test_is_ancestor_true(mock_repo):
    """Test is_ancestor when ancestor relationship exists."""
    repo = mock_repo()
    ancestor = MagicMock()
    descendant = MagicMock()

    # Mock iter_commits to return a history that includes the ancestor
    commit1 = MagicMock()
    commit2 = MagicMock()
    repo.iter_commits.return_value = [descendant, commit1, commit2, ancestor]

    result = is_ancestor(repo, ancestor, descendant)
    assert result is True
    repo.iter_commits.assert_called_once_with(descendant)


@patch("tagger.git_helper.Repo")
def test_is_ancestor_false(mock_repo):
    """Test is_ancestor when no ancestor relationship exists."""
    repo = mock_repo()
    ancestor = MagicMock()
    descendant = MagicMock()
    other_commit = MagicMock()

    # Mock iter_commits to return a history that doesn't include the ancestor
    repo.iter_commits.return_value = [descendant, other_commit]

    result = is_ancestor(repo, ancestor, descendant)
    assert result is False


@patch("tagger.git_helper.Repo")
def test_is_ancestor_same_commit(mock_repo):
    """Test is_ancestor when both commits are the same."""
    repo = mock_repo()
    commit = MagicMock()

    repo.iter_commits.return_value = [commit]

    result = is_ancestor(repo, commit, commit)
    assert result is True


# Test cases for get_last_merged_commits
@patch("tagger.git_helper.Repo")
def test_get_last_merged_commits_success(mock_repo):
    """Test get_last_merged_commits with valid last merge commit."""
    repo = mock_repo()
    user_commit = MagicMock()
    user_commit.hexsha = "merge123"

    # Mock iter_commits to return the user_commit as the last merge
    repo.iter_commits.return_value = iter([user_commit])

    expected_commits = [MagicMock(), MagicMock()]

    with patch("tagger.git_helper.get_commits_from_merge_commit", return_value=expected_commits):
        result = get_last_merged_commits(repo, user_commit)
        assert result == expected_commits


@patch("tagger.git_helper.Repo")
def test_get_last_merged_commits_not_last_merge(mock_repo):
    """Test get_last_merged_commits when user commit is not the last merge."""
    repo = mock_repo()
    user_commit = MagicMock()
    user_commit.hexsha = "notlast"

    last_merge = MagicMock()
    last_merge.hexsha = "actuallast"

    # Mock iter_commits to return a different commit as the last merge
    repo.iter_commits.return_value = iter([last_merge])

    with pytest.raises(CommitAnalysisException) as exc_info:
        get_last_merged_commits(repo, user_commit)

    assert "notlast is a not a merge commit or not the last merge commit!" in str(exc_info.value)


# Test cases for get_merge_commits_between edge cases
def test_get_merge_commits_between_no_merges():
    """Test get_merge_commits_between when no merge commits exist."""
    repo = MagicMock()

    # Create regular commits (single parent each)
    commit1 = MagicMock()
    commit1.parents = [MagicMock()]
    commit1.hexsha = "regular1"
    commit1.message = "Regular commit 1"

    commit2 = MagicMock()
    commit2.parents = [MagicMock()]
    commit2.hexsha = "regular2"
    commit2.message = "Regular commit 2"

    repo.iter_commits.return_value = [commit1, commit2]

    result = get_merge_commits_between(repo, "new_sha", "old_sha")
    assert not result


def test_get_merge_commits_between_empty_range():
    """Test get_merge_commits_between with empty commit range."""
    repo = MagicMock()
    repo.iter_commits.return_value = []

    result = get_merge_commits_between(repo, "same_sha", "same_sha")
    assert not result


def test_get_merge_commits_between_mixed_commits():
    """Test get_merge_commits_between with mix of regular and merge commits."""
    repo = MagicMock()

    # Create a mix of regular and merge commits
    regular_commit = MagicMock()
    regular_commit.parents = [MagicMock()]
    regular_commit.hexsha = "regular"
    regular_commit.message = "Regular commit"

    merge_commit1 = MagicMock()
    merge_commit1.parents = [MagicMock(), MagicMock()]
    merge_commit1.hexsha = "merge1"
    merge_commit1.message = "Merge commit 1"

    merge_commit2 = MagicMock()
    merge_commit2.parents = [MagicMock(), MagicMock()]
    merge_commit2.hexsha = "merge2"
    merge_commit2.message = "Merge commit 2"

    octopus_merge = MagicMock()
    octopus_merge.parents = [MagicMock(), MagicMock(), MagicMock()]
    octopus_merge.hexsha = "octopus"
    octopus_merge.message = "Octopus merge"

    repo.iter_commits.return_value = [regular_commit, merge_commit1, merge_commit2, octopus_merge]

    result = get_merge_commits_between(repo, "new_sha", "old_sha")

    # Should return only merge commits (including octopus merge)
    expected = [merge_commit1, merge_commit2, octopus_merge]
    assert result == expected


# Test cases for error conditions and edge cases
def test_get_merge_commits_between_large_dataset():
    """Test get_merge_commits_between with large number of commits."""
    repo = MagicMock()

    # Create many commits
    commits = []
    for i in range(100):
        commit = MagicMock()
        # Every 10th commit is a merge
        if i % 10 == 0:
            commit.parents = [MagicMock(), MagicMock()]
        else:
            commit.parents = [MagicMock()]
        commit.hexsha = f"commit{i}"
        commit.message = f"Commit {i}"
        commits.append(commit)

    repo.iter_commits.return_value = commits

    result = get_merge_commits_between(repo, "new_sha", "old_sha")

    # Should return 10 merge commits (every 10th commit)
    assert len(result) == 10
    for commit in result:
        assert len(commit.parents) > 1


# Performance and stress test cases
@patch("tagger.git_helper.Repo")
def test_get_commits_from_merge_commit_many_commits(mock_repo):
    """Test get_commits_from_merge_commit with many commits to sort."""
    repo = mock_repo()
    user_commit = MagicMock()
    parent_commit_1 = MagicMock()
    parent_commit_2 = MagicMock()

    user_commit.parents = [parent_commit_1, parent_commit_2]
    user_commit.hexsha = "mocksha"
    user_commit.message = "Mock merge commit message"
    user_commit.authored_datetime = datetime(2023, 1, 1, 12, 0, 0)

    parent_commit_1.hexsha = "parent1sha"
    parent_commit_1.message = "Parent 1 commit message"
    parent_commit_2.hexsha = "parent2sha"
    parent_commit_2.message = "Parent 2 commit message"

    # Create many commits with various timestamps
    base_time = datetime(2023, 1, 1, 10, 0, 0)
    mock_commits = []

    for i in range(50):
        commit = MagicMock()
        commit.authored_datetime = base_time + timedelta(minutes=i)
        commit.message = f"Commit {i}"
        commit.hexsha = f"commit{i}"
        commit.parents = [MagicMock()]
        commit.author.email = f"dev{i}@example.com"
        mock_commits.append(commit)

    # Shuffle the commits to test sorting
    shuffled_commits = mock_commits.copy()
    random.shuffle(shuffled_commits)

    repo.merge_base.return_value = [MagicMock()]

    with (
        patch("tagger.git_helper.is_ancestor", return_value=False),
        patch("tagger.git_helper._get_commits_between", return_value=shuffled_commits),
    ):
        result = get_commits_from_merge_commit(repo, user_commit)

        # Verify correct sorting (chronological order)
        assert len(result) == 50
        for i in range(len(result) - 1):
            assert result[i].authored_datetime <= result[i + 1].authored_datetime
