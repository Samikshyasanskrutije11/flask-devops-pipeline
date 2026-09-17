# ---------- build/runtime image ----------
FROM python:3.11-slim

ARG APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION} \
    ENVIRONMENT=production \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=5000

WORKDIR /usr/src/app

# Install deps first so Docker can cache this layer
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# Run as a non-root user
RUN useradd --create-home --shell /bin/bash appuser && chown -R appuser:appuser /usr/src/app
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:5000/health').status==200 else 1)"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
