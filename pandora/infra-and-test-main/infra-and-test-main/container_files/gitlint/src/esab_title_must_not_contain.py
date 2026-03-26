"""File implementing ESAB1 gitlint rule."""

# THIS SOURCE IS CONFIDENTIAL AND PROPRIETARY TO THE ESAB GROUP OF COMPANIES
# AND MAY NOT BE REPRODUCED, PUBLISHED OR DISCLOSED TO OTHERS WITHOUT ESAB
# AUTHORISATION. COPYRIGHT (c) ESAB AB 2015- . THIS WORK IS UNPUBLISHED.
# ESAB AB DOES NOT WARRANT OR ASSUME ANY LEGAL LIABILITY OR RESPONSIBILITY FOR
# THE ACCURACY, COMPLETENESS, USEFULNESS, OR COMMERCIAL ABILITY OF THIS SOURCE.
import re
from gitlint.rules import LineRule, RuleViolation, CommitMessageTitle


class TitleMustNotContain(LineRule):
    """Rule enforcing that no title contains any issue keys."""

    id = "ESAB1"
    name = "title-must-not-contain"

    target = CommitMessageTitle

    def validate(self, title, _commit):
        """Check first line for common ESAB issue keys."""
        match = re.search(r"(ADT)[A-Z]{0,1}-\d+", title)
        if match:
            msg = f"Commit message title contains issue key: {match.group()}"
            return [RuleViolation(self.id, msg, title)]

        return None
