FROM python:3.12 AS builder
WORKDIR /app
RUN apt update && apt install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*
RUN --mount=type=bind,source=requirements.txt,target=/app/requirements.txt pip wheel --no-cache-dir --no-deps -r /app/requirements.txt --wheel-dir /app/wheels




FROM python:3.12-slim
COPY --from=builder /app/wheels /wheels

RUN apt update && apt install -y --no-install-recommends libpq-dev && rm -rf /var/lib/apt/lists/* && pip install --no-cache --no-cache-dir /wheels/*

COPY app.py /app/
RUN addgroup --system app && adduser --system --group app && chown app:app /app/

USER app
WORKDIR /app
CMD ["python", "app.py"]