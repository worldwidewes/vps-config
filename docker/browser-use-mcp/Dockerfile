FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    BROWSER_USE_HEADLESS=true \
    BROWSER_USE_DISABLE_SECURITY=false

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        chromium \
        fonts-dejavu-core \
        fonts-freefont-ttf \
        fonts-liberation \
        fonts-noto-core \
        fonts-unifont \
    && ln -sf /usr/bin/chromium /usr/bin/chromium-browser \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/browser-use \
    && /opt/browser-use/bin/pip install --no-cache-dir "browser-use[cli]==0.13.10" \
    && python -m venv /opt/mcp-proxy \
    && /opt/mcp-proxy/bin/pip install --no-cache-dir \
        "mcp-proxy==0.12.0" \
        "mcp==1.26.0"

RUN useradd --create-home --uid 10001 --shell /usr/sbin/nologin browseruse \
    && mkdir -p /home/browseruse/.config/browseruse \
    && chown -R browseruse:browseruse /home/browseruse

ENV HOME=/home/browseruse
USER browseruse

EXPOSE 8080

ENTRYPOINT ["/opt/mcp-proxy/bin/mcp-proxy"]
CMD ["--pass-environment", "--host", "0.0.0.0", "--port", "8080", "--", "/opt/browser-use/bin/browser-use", "--mcp"]
