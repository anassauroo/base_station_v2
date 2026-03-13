import os, json, time, glob
from kafka import KafkaConsumer
import cv2

BROKER = os.getenv("KAFKA_BROKER", "localhost:29092")
TOPIC = os.getenv("TOPIC", "results.detections")
FRAMES_ROOT = os.getenv("FRAMES_ROOT", "./frames")

def latest_jpg(stream: str):
    patt1 = os.path.join(FRAMES_ROOT, stream, "*.jpg")
    files = glob.glob(patt1)
    if not files:
        # fallback: tenta achar jpgs em qualquer subpasta que contenha o nome do stream
        files = glob.glob(os.path.join(FRAMES_ROOT, "**", "*.jpg"), recursive=True)
        files = [f for f in files if f"/{stream}/" in f.replace("\\", "/")]
    if not files:
        return None
    return max(files, key=os.path.getmtime)

def parse_dets(msg):
    """
    Tenta suportar formatos comuns:
    A) {"stream":"cam1","detections":[{"x1":..,"y1":..,"x2":..,"y2":..,"label":"person"}]}
    B) {"stream":"cam1","detections":[{"xyxy":[x1,y1,x2,y2], "cls":"person"}]}
    C) {"stream":"cam1","detections":[{"xywhn":[cx,cy,w,h]}]} (normalizado 0..1)
    """
    stream = msg.get("stream") or msg.get("stream_name") or msg.get("camera") or msg.get("name")
    dets = msg.get("detections") or msg.get("dets") or msg.get("objects") or []
    return stream, dets

def to_xyxy(det, W, H):
    if "xyxy" in det and len(det["xyxy"]) == 4:
        x1,y1,x2,y2 = det["xyxy"]
        return int(x1), int(y1), int(x2), int(y2)
    if all(k in det for k in ("x1","y1","x2","y2")):
        return int(det["x1"]), int(det["y1"]), int(det["x2"]), int(det["y2"])
    if "xywhn" in det and len(det["xywhn"]) == 4:
        cx,cy,w,h = det["xywhn"]
        x1 = (cx - w/2) * W
        y1 = (cy - h/2) * H
        x2 = (cx + w/2) * W
        y2 = (cy + h/2) * H
        return int(x1), int(y1), int(x2), int(y2)
    return None

consumer = KafkaConsumer(
    TOPIC,
    bootstrap_servers=[BROKER],
    auto_offset_reset="latest",
    enable_auto_commit=True,
    group_id="overlay-demo",
    value_deserializer=lambda v: json.loads(v.decode("utf-8"))
)

print(f"[overlay] listening {TOPIC} @ {BROKER}")
for message in consumer:
    msg = message.value
    stream, dets = parse_dets(msg)
    if not stream:
        print("[overlay] msg sem stream id:", msg.keys())
        continue

    img_path = latest_jpg(stream)
    if not img_path:
        print(f"[overlay] sem frames p/ {stream} ainda (esperando...)")
        continue

    img = cv2.imread(img_path)
    if img is None:
        print(f"[overlay] falha lendo {img_path}")
        continue

    H, W = img.shape[:2]
    count = 0
    for det in dets:
        box = to_xyxy(det, W, H)
        if not box:
            continue
        x1,y1,x2,y2 = box
        # clip simples
        x1 = max(0, min(W-1, x1)); x2 = max(0, min(W-1, x2))
        y1 = max(0, min(H-1, y1)); y2 = max(0, min(H-1, y2))
        if x2 <= x1 or y2 <= y1:
            continue

        label = det.get("label") or det.get("cls") or det.get("class") or "obj"
        conf = det.get("conf") or det.get("confidence")
        txt = f"{label}" + (f" {conf:.2f}" if isinstance(conf, (int,float)) else "")

        cv2.rectangle(img, (x1,y1), (x2,y2), (0,255,0), 2)
        cv2.putText(img, txt, (x1, max(15, y1-5)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0,255,0), 1, cv2.LINE_AA)
        count += 1

    out_path = os.path.join(os.path.dirname(img_path), "annotated_latest.jpg")
    cv2.imwrite(out_path, img)
    print(f"[overlay] {stream}: {count} box(es) | base={os.path.basename(img_path)} | saved={out_path}")
