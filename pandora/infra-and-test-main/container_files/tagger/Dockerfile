FROM python:3.13-alpine

# Bump image version for any changes
LABEL version="1.1.4"

COPY . .

RUN apk add --no-cache \
    git="2.49.0-r0" \
    curl="8.14.1-r0" \
    jq="1.8.0-r0" \
    bash="5.2.37-r0" \
    wget="1.25.0-r1"

RUN --mount=type=secret,id=gitlab_token \
    --mount=type=secret,id=gitlab_project_id \
    bash -c '\
      export GITLAB_TOKEN=$(cat /run/secrets/gitlab_token) && \
      export GITLAB_PROJECT_ID=$(cat /run/secrets/gitlab_project_id) && \
      export PIP_EXTRA_INDEX_URL="https://gitlab-ci-token:${GITLAB_TOKEN}@gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}/packages/pypi/simple" && \
      pip install --upgrade pip && \
      pip install .[dev] --root-user-action=ignore \
    '

RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

RUN pytest
