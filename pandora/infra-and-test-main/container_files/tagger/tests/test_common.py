from unittest.mock import MagicMock, call, patch

from git import Commit
from tagger.common import bump_semver_version, get_bump_operation, get_type_and_severity


def test_bump_semver_version_normal_development():
    next_version, bump_name = bump_semver_version("1.1.0", "PATCH")
    assert next_version == "1.1.1"
    assert bump_name == "PATCH"

    next_version, bump_name = bump_semver_version("1.1.0", "MINOR")
    assert next_version == "1.2.0"
    assert bump_name == "MINOR"

    next_version, bump_name = bump_semver_version("1.1.0", "MAJOR")
    assert next_version == "2.0.0"
    assert bump_name == "MAJOR"

    next_version, bump_name = bump_semver_version("1.1.0-1", "PRE_RELEASE")
    assert next_version == "1.1.0-2"
    assert bump_name == "PRE_RELEASE"


# We should never bump the major version if it is zero, i.e., still in initial development.
def test_bump_semver_version__initial_devevelopment():
    next_version, bump_name = bump_semver_version("0.1.0", "PATCH")
    assert next_version == "0.1.1"
    assert bump_name == "PATCH"

    next_version, bump_name = bump_semver_version("0.1.0", "MINOR")
    assert next_version == "0.2.0"
    assert bump_name == "MINOR"

    next_version, bump_name = bump_semver_version("0.1.0", "MAJOR")
    assert next_version == "0.2.0"
    assert bump_name == "MINOR"

    next_version, bump_name = bump_semver_version("0.1.0", "PRE_RELEASE")
    assert next_version == "0.1.0-1"
    assert bump_name == "PRE_RELEASE"


def test_bump_semver_version_no_new_version_needed():
    next_version, bump_name = bump_semver_version("0.1.1", "")
    assert next_version == "0.1.1"
    assert bump_name == ""


def test_parse_commit_message__breaking_change_in_summary():
    summary = "type!: Subject text"
    trailers = {}

    _, breaking_change = get_type_and_severity(summary, trailers)

    assert breaking_change


def test_parse_commit_message__breaking_change_in_trailers():
    summary = "type: Subject text"
    trailers = {"BREAKING-change": ["Reason for breaking change"]}

    _, breaking_change = get_type_and_severity(summary, trailers)

    assert breaking_change


def test_parse_commit_message__no_breaking_change_trailer():
    summary = "type: Subject text"
    trailers = {"Issues": ["ADT-123"]}

    type_of_change, breaking_change = get_type_and_severity(summary, trailers)

    assert type_of_change == "type"
    assert not breaking_change


def test_parse_commit_message__type_without_scope_in_summary():
    summary = "type: Subject text"

    type_of_change, _ = get_type_and_severity(summary, {})

    assert type_of_change == "type"


def test_parse_commit_message__type_with_scope_in_summary():
    summary = "type(scope): Subject text"

    type_of_change, _ = get_type_and_severity(summary, {})

    assert type_of_change == "type"


@patch("tagger.common.get_type_and_severity")
def test_get_change_type__minor_feat(mock_parse_commit_msg):
    mock_parse_commit_msg.side_effect = [("fix", False), ("feat", False), ("perf", False)]

    mock_commit1 = MagicMock(spec=Commit)
    mock_commit2 = MagicMock(spec=Commit)
    mock_commit3 = MagicMock(spec=Commit)

    mock_commit1.hexsha = "hexsha1"
    mock_commit1.summary = "fix: Summary1"
    mock_commit1.trailers_dict = {"key1": ["reason1", "reason1"]}

    mock_commit2.hexsha = "hexsha2"
    mock_commit2.summary = "feat: Summary2"
    mock_commit2.trailers_dict = {"key2": ["reason2", "reason2"]}

    mock_commit3.hexsha = "hexsha3"
    mock_commit3.summary = "perf: Summary3"
    mock_commit3.trailers_dict = {"key3": ["reason3", "reason3"]}

    commits = [mock_commit1, mock_commit2, mock_commit3]

    bump_name, bump_type = get_bump_operation(commits, pre_release=False)

    assert bump_name == "MINOR"
    assert bump_type == "feat"
    mock_parse_commit_msg.assert_has_calls(
        [
            call("fix: Summary1", {"key1": ["reason1", "reason1"]}),
            call("feat: Summary2", {"key2": ["reason2", "reason2"]}),
            call("perf: Summary3", {"key3": ["reason3", "reason3"]}),
        ]
    )


@patch("tagger.common.get_type_and_severity")
def test_get_change_type__patch_fix(mock_parse_commit_msg):
    mock_parse_commit_msg.side_effect = [("fix", False), ("ci", False), ("test", False)]

    mock_commit1 = MagicMock(spec=Commit)
    mock_commit2 = MagicMock(spec=Commit)
    mock_commit3 = MagicMock(spec=Commit)

    mock_commit1.hexsha = "hexsha1"
    mock_commit1.summary = "fix: Summary1"
    mock_commit1.trailers_dict = {"key1": ["reason1", "reason1"]}

    mock_commit2.hexsha = "hexsha2"
    mock_commit2.summary = "ci: Summary2"
    mock_commit2.trailers_dict = {"key2": ["reason2", "reason2"]}

    mock_commit3.hexsha = "hexsha3"
    mock_commit3.summary = "test: Summary3"
    mock_commit3.trailers_dict = {"key3": ["reason3", "reason3"]}

    commits = [mock_commit1, mock_commit2, mock_commit3]

    bump_name, bump_type = get_bump_operation(commits, pre_release=False)

    assert bump_name == "PATCH"
    assert bump_type == "fix"
    mock_parse_commit_msg.assert_has_calls(
        [
            call("fix: Summary1", {"key1": ["reason1", "reason1"]}),
            call("ci: Summary2", {"key2": ["reason2", "reason2"]}),
            call("test: Summary3", {"key3": ["reason3", "reason3"]}),
        ]
    )


@patch("tagger.common.get_type_and_severity")
def test_get_change_type__patch_perf(mock_parse_commit_msg):
    mock_parse_commit_msg.side_effect = [("perf", False), ("ci", False), ("test", False)]

    mock_commit1 = MagicMock(spec=Commit)
    mock_commit2 = MagicMock(spec=Commit)
    mock_commit3 = MagicMock(spec=Commit)

    mock_commit1.hexsha = "hexsha1"
    mock_commit1.summary = "perf: Summary1"
    mock_commit1.trailers_dict = {"key1": ["reason1", "reason1"]}

    mock_commit2.hexsha = "hexsha2"
    mock_commit2.summary = "ci: Summary2"
    mock_commit2.trailers_dict = {"key2": ["reason2", "reason2"]}

    mock_commit3.hexsha = "hexsha3"
    mock_commit3.summary = "test: Summary3"
    mock_commit3.trailers_dict = {"key3": ["reason3", "reason3"]}

    commits = [mock_commit1, mock_commit2, mock_commit3]

    bump_name, bump_type = get_bump_operation(commits, pre_release=False)

    assert bump_name == "PATCH"
    assert bump_type == "perf"
    mock_parse_commit_msg.assert_has_calls(
        [
            call("perf: Summary1", {"key1": ["reason1", "reason1"]}),
            call("ci: Summary2", {"key2": ["reason2", "reason2"]}),
            call("test: Summary3", {"key3": ["reason3", "reason3"]}),
        ]
    )


@patch("tagger.common.get_type_and_severity")
def test_get_change_type__major(mock_parse_commit_msg):
    mock_parse_commit_msg.side_effect = [("fix", False), ("feat", True)]

    mock_commit1 = MagicMock(spec=Commit)
    mock_commit2 = MagicMock(spec=Commit)
    mock_commit3 = MagicMock(spec=Commit)

    mock_commit1.hexsha = "hexsha1"
    mock_commit1.summary = "fix: Summary1"
    mock_commit1.trailers_dict = {"key1": ["reason1", "reason1"]}

    mock_commit2.hexsha = "hexsha2"
    mock_commit2.summary = "feat: Summary2"
    mock_commit2.trailers_dict = {"BREAKING-CHANGE": ["reason2"]}

    mock_commit3.hexsha = "hexsha3"
    mock_commit3.summary = "test: Summary3"
    mock_commit3.trailers_dict = {"key3": ["reason3", "reason3"]}

    commits = [mock_commit1, mock_commit2, mock_commit3]

    bump_name, bump_type = get_bump_operation(commits, pre_release=False)

    assert bump_name == "MAJOR"
    assert bump_type == "feat!"
    mock_parse_commit_msg.assert_has_calls(
        [
            call("fix: Summary1", {"key1": ["reason1", "reason1"]}),
            call("feat: Summary2", {"BREAKING-CHANGE": ["reason2"]}),
        ]
    )
    assert mock_parse_commit_msg.call_count == 2


@patch("tagger.common.get_type_and_severity")
def test_get_change_type__docs_breaking_change(mock_parse_commit_msg):
    mock_parse_commit_msg.side_effect = [("fix", False), ("docs", True)]

    mock_commit1 = MagicMock(spec=Commit)
    mock_commit2 = MagicMock(spec=Commit)

    mock_commit1.hexsha = "hexsha1"
    mock_commit1.summary = "fix: Summary1"
    mock_commit1.trailers_dict = {"key1": ["reason1", "reason1"]}

    mock_commit2.hexsha = "hexsha2"
    mock_commit2.summary = "docs: Summary2"
    mock_commit2.trailers_dict = {"BREAKING-CHANGE": ["reason2"]}

    commits = [mock_commit1, mock_commit2]

    bump_name, bump_type = get_bump_operation(commits, pre_release=False)

    assert bump_name == "MAJOR"
    assert bump_type == "docs!"
    mock_parse_commit_msg.assert_has_calls(
        [
            call("fix: Summary1", {"key1": ["reason1", "reason1"]}),
            call("docs: Summary2", {"BREAKING-CHANGE": ["reason2"]}),
        ]
    )
    assert mock_parse_commit_msg.call_count == 2


@patch("tagger.common.get_type_and_severity")
def test_get_change_type__no_bump(mock_parse_commit_msg):
    mock_parse_commit_msg.side_effect = [("ci", False)]

    mock_commit1 = MagicMock(spec=Commit)

    mock_commit1.hexsha = "hexsha1"
    mock_commit1.summary = "ci: Summary1"
    mock_commit1.trailers_dict = {"Issues": ["NONE"]}

    commits = [mock_commit1]

    bump_name, bump_type = get_bump_operation(commits, pre_release=False)

    assert bump_name == ""
    assert bump_type == ""
    mock_parse_commit_msg.assert_has_calls(
        [
            call("ci: Summary1", {"Issues": ["NONE"]}),
        ]
    )
    assert mock_parse_commit_msg.call_count == 1


@patch("tagger.common.get_type_and_severity")
def test_get_change_type__pre_release(mock_parse_commit_msg):
    mock_parse_commit_msg.side_effect = [("fix", False), ("feat", True)]

    mock_commit1 = MagicMock(spec=Commit)
    mock_commit2 = MagicMock(spec=Commit)
    mock_commit3 = MagicMock(spec=Commit)

    mock_commit1.hexsha = "hexsha1"
    mock_commit1.summary = "fix: Summary1"
    mock_commit1.trailers_dict = {"key1": ["reason1", "reason1"]}

    mock_commit2.hexsha = "hexsha2"
    mock_commit2.summary = "feat: Summary2"
    mock_commit2.trailers_dict = {"BREAKING-CHANGE": ["reason2"]}

    mock_commit3.hexsha = "hexsha3"
    mock_commit3.summary = "test: Summary3"
    mock_commit3.trailers_dict = {"key3": ["reason3", "reason3"]}

    commits = [mock_commit1, mock_commit2, mock_commit3]

    bump_name, bump_type = get_bump_operation(commits, pre_release=True)

    assert bump_name == "PRE_RELEASE"
    assert bump_type == "feat!"
