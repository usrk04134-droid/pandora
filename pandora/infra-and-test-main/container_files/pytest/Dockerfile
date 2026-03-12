FROM python:3.12-slim-bookworm

# Bump image version for any changes
LABEL version="0.1.0"

RUN pip install --upgrade pip && \
    pip install \
        "click==8.1" \
        "click-repl==0.3" \
        "loguru==0.7.3" \
        "pydantic==2.11.7" \
        "pytest==8.4.1" \
        "requests==2.32" \
        "websockets==15.0.1"
