import glob
import json
import os
import re
import subprocess
import tempfile
import threading
from pathlib import Path

import numpy as np
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

API_KEY = os.getenv("API_KEY", "")
MAX_DURATION = int(os.getenv("MAX_DURATION", "600"))
CACHE_DIR = Path(os.getenv("CACHE_DIR", "/data/cache"))
CACHE_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Chordify Audio Analysis Engine", version="1.1.0")

# "*" + allow_credentials=True é combinação insegura; a API não usa cookies.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)

# Modelos madmom carregados sob demanda (e uma única vez, mesmo com requisições simultâneas)
chord_feat = chord_rec = beat_act = beat_trk = None
_init_lock = threading.Lock()

# Análise é pesada: limita as simultâneas e evita analisar o mesmo vídeo 2x
_slots = threading.Semaphore(int(os.getenv("MAX_CONCURRENT", "2")))
_locks: dict[str, threading.Lock] = {}
_locks_guard = threading.Lock()

VIDEO_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")


def _init_models():
    global chord_feat, chord_rec, beat_act, beat_trk
    with _init_lock:
        if chord_feat is not None:
            return
        try:
            from madmom.features.beats import (DBNBeatTrackingProcessor,
                                               RNNBeatProcessor)
            from madmom.features.chords import (CNNChordFeatureProcessor,
                                                CRFChordRecognitionProcessor)
        except ImportError as e:
            raise RuntimeError(f"madmom não está instalado: {e}")
        chord_feat = CNNChordFeatureProcessor()
        chord_rec = CRFChordRecognitionProcessor()
        beat_act = RNNBeatProcessor()
        beat_trk = DBNBeatTrackingProcessor(fps=100)


def check_key(x_api_key: str = Header(default="")):
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(401, "Chave inválida")


def to_cifra(label: str) -> str:
    """'C:maj' -> 'C', 'A:min' -> 'Am', 'G:7' -> 'G7' ..."""
    root, _, q = label.partition(":")
    mapping = {"maj": "", "min": "m", "7": "7", "min7": "m7", "maj7": "maj7",
               "dim": "dim", "aug": "aug", "sus4": "sus4", "sus2": "sus2"}
    return root + mapping.get(q, q)


def download_wav(video_id: str, workdir: str) -> str:
    out = os.path.join(workdir, "audio.%(ext)s")
    cmd = ["yt-dlp", "--no-playlist", "-x", "--audio-format", "wav",
           "--postprocessor-args", "-ar 44100 -ac 1",
           "--match-filter", f"duration < {MAX_DURATION}",
           "-o", out, f"https://www.youtube.com/watch?v={video_id}"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        raise HTTPException(504, "Tempo esgotado ao baixar o áudio")
    files = glob.glob(os.path.join(workdir, "audio.*"))
    if proc.returncode != 0 or not files:
        msg = (proc.stderr or "").strip()[-300:] or \
            f"Vídeo indisponível ou maior que {MAX_DURATION}s"
        raise HTTPException(502, f"Erro ao obter áudio: {msg}")
    return files[0]


@app.get("/health")
def health():
    return {"status": "ok", "cached_songs": len(list(CACHE_DIR.glob("*.json")))}


@app.get("/analyze/{video_id}", dependencies=[Depends(check_key)])
def analyze(video_id: str):
    if not VIDEO_ID_RE.match(video_id):
        raise HTTPException(400, "videoId inválido")

    cache_file = CACHE_DIR / f"{video_id}.json"
    if cache_file.exists():
        return json.loads(cache_file.read_text())

    with _locks_guard:
        lock = _locks.setdefault(video_id, threading.Lock())
    with lock:
        if cache_file.exists():
            return json.loads(cache_file.read_text())

        _init_models()
        with _slots:
            with tempfile.TemporaryDirectory() as d:
                wav = download_wav(video_id, d)
                chords = chord_rec(chord_feat(wav))
                beats = beat_trk(beat_act(wav))

        bpm = 0
        if len(beats) > 2:
            diff = float(np.median(np.diff(beats)))
            if diff > 0:
                bpm = round(60.0 / diff)

        formatted = [{"start": round(float(s), 3), "end": round(float(e), 3),
                      "chord": to_cifra(c)} for s, e, c in chords if c != "N"]
        if not formatted:
            raise HTTPException(422, "Nenhum acorde detectado")

        data = {"videoId": video_id,
                "bpm": bpm if bpm > 0 else 80,
                "beats": [round(float(b), 3) for b in beats],
                "chords": formatted,
                "duration": round(float(chords[-1][1]), 2)}
        cache_file.write_text(json.dumps(data))
        return data
