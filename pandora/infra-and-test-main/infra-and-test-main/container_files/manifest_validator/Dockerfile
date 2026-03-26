FROM python:3.13.0-slim
LABEL authors="team-godzilla"

# Bump image version for any changes
LABEL version="0.1.0"

WORKDIR /app

COPY validate.py /app/

RUN pip install --no-cache-dir jsonschema pyyaml loguru

ENTRYPOINT ["bash"]
