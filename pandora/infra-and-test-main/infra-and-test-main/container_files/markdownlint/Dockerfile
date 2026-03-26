FROM docker.io/pipelinecomponents/markdownlint:0.14.0

# Bump image version for any changes
LABEL version="0.2.0"

ENV MDLINT_CONFIG="/etc/opt/.mdl_style.rb"

RUN mkdir -p /etc/opt

COPY .mdl_style.rb $MDLINT_CONFIG

RUN apk add --no-cache bash
