"""File implementing ESAB3 gitlint rule."""

# THIS SOURCE IS CONFIDENTIAL AND PROPRIETARY TO THE ESAB GROUP OF COMPANIES
# AND MAY NOT BE REPRODUCED, PUBLISHED OR DISCLOSED TO OTHERS WITHOUT ESAB
# AUTHORISATION. COPYRIGHT (c) ESAB AB 2015- . THIS WORK IS UNPUBLISHED.
# ESAB AB DOES NOT WARRANT OR ASSUME ANY LEGAL LIABILITY OR RESPONSIBILITY FOR
# THE ACCURACY, COMPLETENESS, USEFULNESS, OR COMMERCIAL ABILITY OF THIS SOURCE.
import re
from gitlint.rules import LineRule, RuleViolation, CommitMessageBody


class IssuesTrailerFormat(LineRule):
    """Rule enforcing that all issue references are formatted well."""

    id = "ESAB3"
    name = "issues-trailer-format"

    target = CommitMessageBody

    rgx = r"Issues:\s*(ADT[A-Z]?-\d+)(?:,\s?ADT[A-Z]?-\d+)*"

    def validate(self, line, _commit):
        """Validate all lines starting with "Issues" with the above regexp."""

        if line.startswith("Issues"):
            if re.fullmatch(self.rgx, line) is None:
                msg = ('"Issues" line is ill-formatted. '
                       "Please follow .gitmessage guidelines.")
                return [RuleViolation(self.id, msg, line)]

        return None
