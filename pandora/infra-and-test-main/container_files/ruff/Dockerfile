FROM docker.io/pipelinecomponents/ruff:0.32.0

# Bump image version for any changes
LABEL version="0.4.1"

RUN apk add --no-cache \
    git \
    bash

ENV RUFF_CONFIG="/etc/opt/ruff.toml"

RUN mkdir -p /etc/opt

COPY ruff.toml $RUFF_CONFIG
