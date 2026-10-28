FROM python:3.10-slim

# ffmpeg: conversão do áudio | nodejs: runtime JS que o yt-dlp usa para o YouTube
# build-essential + git: compilar o madmom (extensões Cython)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg nodejs build-essential git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# madmom do PyPI (0.16.1) quebra em Python >= 3.10; usa-se a versão do GitHub.
# Cython e numpy precisam existir ANTES de compilar o madmom.
COPY requirements.txt .
RUN pip install --no-cache-dir cython "numpy<2" \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir git+https://github.com/CPJKU/madmom.git

COPY app.py .

ENV CACHE_DIR=/data/cache
VOLUME /data
EXPOSE 8000

# 1 worker: os modelos ficam em memória; a concorrência é limitada no código
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
