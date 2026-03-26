# Build command:
# docker build -t registry.gitlab.com/esab/abw/plc/aws-platform/aws-platform-env:<IMAGE_VERSION> .
#
# Replace <IMAGE_VERSION> with the desired version tag, for example:
# docker build -t registry.gitlab.com/esab/abw/plc/aws-platform/aws-platform-env:1.0.0 .
#
FROM registry.gitlab.com/esab/abw/plc/apax/apax-ci:0.3.0

# Bump image version for any changes
LABEL version="1.0.1"
LABEL authors="team-godzilla"

RUN apt-get update \
	&& apt-get install -y --no-install-recommends python3 python3-pip iputils-ping \
	&& pip3 install --no-cache-dir --break-system-packages junit-xml loguru requests \
	&& rm -rf /var/lib/apt/lists/*

COPY --chmod=755 utilities/axunit2junit.py /usr/local/bin/axunit2junit
