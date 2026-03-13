"""
Orquestrador simplificado com detecção de objetos.

Este módulo consome mensagens de streams ativos via Kafka, captura frames dos
streams RTSP expostos pelo MediaMTX e executa o modelo YOLO para detectar
objetos. Os frames anotados com bounding boxes são salvos em disco para
visualização posterior. Não há detecção de movimento ou gravação de clipes;
o objetivo é demonstrar como integrar YOLO no pipeline existente.

Configuração via variáveis de ambiente:

* KAFKA_BROKER – endereço do broker Kafka (ex.: "kafka:9092")
* TOPIC – tópico com lista de streams ativos (default: "streams_ativos")
* GROUP_ID – identificador do grupo Kafka para o consumidor
* MEDIAMTX_HOST – host onde o MediaMTX está rodando
* MEDIAMTX_RTSP_PORT – porta RTSP do MediaMTX
* FRAMES_DIR – diretório onde os frames anotados serão salvos
* YOLO_WEIGHTS_URI – caminho para o arquivo de pesos do modelo YOLO. Pode ser
  um caminho local (ex.: "file:///weights/yolov8n.pt") ou remoto (URL
  suportada pela biblioteca ultralytics). O prefixo "file://" será
  removido automaticamente.
* CAPTURE_INTERVAL_S – intervalo em segundos entre capturas consecutivas de
  cada stream (padrão: 1.0)

Para executar este orquestrador, é necessário que a imagem Docker inclua o
ffmpeg (para captura via rtsp) e a biblioteca ultralytics (para YOLO).
"""

import os
import asyncio
import json
import time
from pathlib import Path
from typing import Dict, Set

import cv2
import numpy as np
from aiokafka import AIOKafkaConsumer

try:
    from ultralytics import YOLO  # type: ignore
except ImportError:
    YOLO = None  # Será inicializado abaixo, se disponível


# =========================
# Configurações via env
# =========================
BROKERS = os.getenv("KAFKA_BROKER", "kafka:9092")
TOPIC = os.getenv("TOPIC", "streams_ativos")
GROUP_ID = os.getenv("GROUP_ID", "streams-logger")

MEDIAMTX_HOST = os.getenv("MEDIAMTX_HOST", "mediamtx")
MEDIAMTX_RTSP_PORT = int(os.getenv("MEDIAMTX_RTSP_PORT", "8554"))

FRAMES_DIR = Path(os.getenv("FRAMES_DIR", "/app/frames"))
FRAMES_DIR.mkdir(parents=True, exist_ok=True)

CAPTURE_INTERVAL_S = float(os.getenv("CAPTURE_INTERVAL_S", "1.0"))

YOLO_WEIGHTS_URI = os.getenv("YOLO_WEIGHTS_URI", "file:///weights/yolov8n.pt")


# =========================
# Inicializa o modelo YOLO
# =========================
def _load_model() -> YOLO:
    if YOLO is None:
        raise ImportError("ultralytics não está instalado. Adicione 'ultralytics' \
                         ao requirements.txt e instale-o no container.")
    # Remove prefixo file:// se presente e resolve caminho
    weights_path = YOLO_WEIGHTS_URI
    if weights_path.startswith("file://"):
        weights_path = weights_path[7:]
    return YOLO(weights_path)


model = None  # type: ignore


# =========================
# Detecção e anotação de um frame
# =========================
def annotate_image(image: np.ndarray) -> np.ndarray:
    """Executa o modelo YOLO no frame e desenha bounding boxes.

    Args:
        image: imagem BGR carregada via OpenCV.

    Returns:
        Nova imagem BGR com caixas desenhadas.
    """
    global model
    if model is None:
        model = _load_model()
    # Executa a inferência; desativa stream_processing para obter resultados imediatos
    results = model.predict(source=image, stream=False)
    # `results` retorna uma lista; pegamos o primeiro item
    if not results:
        return image
    res = results[0]
    # Itera sobre as detecções
    for box in res.boxes:
        # Coordenadas xyxy e classe/score
        x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
        conf = float(box.conf)
        cls_idx = int(box.cls)
        label = model.names.get(cls_idx, str(cls_idx))
        # Desenha retângulo
        cv2.rectangle(image, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 2)
        # Escreve label e confiança
        text = f"{label} {conf:.2f}"
        y_text = int(y1) - 5 if y1 - 5 > 10 else int(y1) + 20
        cv2.putText(image, text, (int(x1), y_text), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
    return image


# =========================
# Tarefas de captura para cada stream
# =========================
capture_tasks: Dict[str, asyncio.Task] = {}
active_streams: Set[str] = set()


async def capture_loop(stream_name: str) -> None:
    """Processa continuamente um stream: captura frames via OpenCV, executa YOLO
    e salva os frames anotados.
    """
    rtsp_url = f"rtsp://{MEDIAMTX_HOST}:{MEDIAMTX_RTSP_PORT}/{stream_name}"
    out_dir = FRAMES_DIR / stream_name
    out_dir.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(rtsp_url)
    if not cap.isOpened():
        print(f"[yolo] Falha ao abrir stream {rtsp_url}")
        return
    print(f"[yolo] Capturando stream {stream_name}…")
    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                await asyncio.sleep(1.0)
                continue
            annotated = annotate_image(frame.copy())
            # Salva com timestamp em milissegundos
            timestamp_ms = int(time.time() * 1000)
            out_file = out_dir / f"det_{timestamp_ms}.jpg"
            cv2.imwrite(str(out_file), annotated)
            # Aguarda o intervalo configurado
            await asyncio.sleep(CAPTURE_INTERVAL_S)
    except asyncio.CancelledError:
        pass
    finally:
        cap.release()
        print(f"[yolo] Parando captura do stream {stream_name}")


def extract_stream_names(streams) -> list[str]:
    """Extrai nomes de streams a partir de uma lista de strings ou dicts."""
    if not streams:
        return []
    if isinstance(streams[0], str):
        return [s for s in streams if isinstance(s, str) and s.strip()]
    names = []
    for s in streams:
        if isinstance(s, dict):
            n = s.get("nome") or s.get("source_id") or s.get("path") or s.get("stream")
            if isinstance(n, str) and n.strip():
                names.append(n)
    return names


async def consume_stream_list() -> None:
    """Consome o tópico Kafka com snapshots de streams e gerencia as tarefas."""
    consumer = AIOKafkaConsumer(
        TOPIC,
        bootstrap_servers=BROKERS,
        group_id=GROUP_ID,
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        key_deserializer=lambda k: k.decode("utf-8") if k else None,
        auto_offset_reset="latest",
        enable_auto_commit=True,
    )
    await consumer.start()
    print(f"[yolo] Consumidor conectado no tópico '{TOPIC}' ({BROKERS})")
    try:
        async for msg in consumer:
            payload = msg.value
            streams = extract_stream_names(payload.get("streams", []))
            current = set(streams)
            # Inicia captura para streams novos
            for s in current - active_streams:
                active_streams.add(s)
                task = asyncio.create_task(capture_loop(s))
                capture_tasks[s] = task
            # Cancela captura de streams que saíram
            for s in active_streams - current:
                task = capture_tasks.pop(s, None)
                if task:
                    task.cancel()
                active_streams.discard(s)
    finally:
        await consumer.stop()


async def main_async() -> None:
    await consume_stream_list()


if __name__ == "__main__":
    asyncio.run(main_async())