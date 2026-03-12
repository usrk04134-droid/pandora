"""File implementing ESAB2 gitlint rule."""

# THIS SOURCE IS CONFIDENTIAL AND PROPRIETARY TO THE ESAB GROUP OF COMPANIES
# AND MAY NOT BE REPRODUCED, PUBLISHED OR DISCLOSED TO OTHERS WITHOUT ESAB
# AUTHORISATION. COPYRIGHT (c) ESAB AB 2015- . THIS WORK IS UNPUBLISHED.
# ESAB AB DOES NOT WARRANT OR ASSUME ANY LEGAL LIABILITY OR RESPONSIBILITY FOR
# THE ACCURACY, COMPLETENESS, USEFULNESS, OR COMMERCIAL ABILITY OF THIS SOURCE.
from gitlint.rules import CommitRule, RuleViolation


class IssuesTrailerExists(CommitRule):
    """Rule enforcing that each commit trailer contains at least one issue
       reference."""

    id = "ESAB2"
    name = "issues-trailer-exists"

    err_msg = 'Commit message does not end with an "Issues" reference'

    def validate(self, commit):
        """Check last line for required prefix."""
        if commit.message.body is None or len(commit.message.body) < 2:
            return [RuleViolation(self.id, self.err_msg, line_nr=3)]

        last_line = list(filter(None, commit.message.body))[-1]
        last_line_nr = len(commit.message.body)

        if not last_line.startswith("Issues"):
            return [RuleViolation(self.id, self.err_msg, line_nr=last_line_nr)]

        return None
