FROM python:3.12-slim-bookworm

# Bump image version for any changes
LABEL version="0.3.0"

ENV GITLINT_CONFIG="/etc/opt/.gitlint"

COPY .gitlint $GITLINT_CONFIG

RUN apt-get -y update &&  \
    apt-get install --no-install-recommends -y \
    git="1:2.39.5-0+deb12u3" \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

RUN pip install gitlint==0.19.1

# ESAB gitlint rules
COPY src/*.py /usr/local/lib/python3.12/site-packages/gitlint/contrib/rules/
