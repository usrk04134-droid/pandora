FROM docker.io/davidanson/markdownlint-cli2:v0.18.1
ENTRYPOINT []
WORKDIR /
USER root

# Bump image version for any changes
LABEL version="0.2.3"

# Note! When using the markdownlint-cli2 tool, the config file must be in the directory being linted
ENV MDLINT_CONFIG="/etc/opt/.markdownlint-cli2.yaml"

RUN mkdir -p /etc/opt

# Copy the markdownlint config file into the container
COPY .markdownlint-cli2.yaml $MDLINT_CONFIG

RUN apk add --no-cache bash
