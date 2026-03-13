FROM python:3.11-slim

# Desativa criação de arquivos .pyc e buffer no stdout
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Instala dependências do sistema; inclui ffmpeg para captura de frames
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Instala dependências Python (inclui ultralytics para YOLO)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia a aplicação
COPY app.py .

# Define usuário não-root
RUN useradd -m appuser
USER appuser

# Variáveis padrão para conectar ao Kafka e ao MediaMTX; podem ser sobrescritas via compose
ENV KAFKA_BROKER=kafka:9092 \
    TOPIC=streams_ativos \
    GROUP_ID=streams-logger \
    MEDIAMTX_HOST=mediamtx \
    MEDIAMTX_RTSP_PORT=8554 \
    FRAMES_DIR=/app/frames \
    YOLO_WEIGHTS_URI=file:///weights/yolov8n.pt

ENTRYPOINT ["python", "app.py"]