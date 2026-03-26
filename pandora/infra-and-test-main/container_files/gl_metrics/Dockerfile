FROM python:3.13-alpine

# Bump image version for any changes
LABEL version="0.1.0"

COPY . .

RUN pip install --upgrade pip && \
    pip install \
        "requests>=2.32.5" \
        "prometheus-client>=0.24.1" \
        "python-gitlab>=8.1.0" \
        "python-dotenv>=1.2.2" \
        --root-user-action=ignore

ENV PYTHONPATH=/src

ENTRYPOINT ["python", "-m"]
CMD ["gl_metrics.main"]
