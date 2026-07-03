FROM python:3.11-slim AS builder
WORKDIR /build

COPY requirements.txt ./
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app

COPY --from=builder /install /usr/local
COPY . .

USER appuser
EXPOSE 8002
ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8002", "app:app"]
