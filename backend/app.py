import os
import glob
import tempfile
import subprocess
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Chordify Audio Analysis Engine",
    description="Backend para extração de áudio do YouTube e reconhecimento acústico de acordes via madmom",
    version="1.0.0",
)

# Permite acesso CORS para o app Flutter Web e Desktop
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modelos madmom inicializados sob demanda para economizar memória
chord_feat = None
chord_rec = None
beat_act = None
beat_trk = None

CACHE = {}  # Em produção pode ser substituído por Redis ou SQLite

def _init_models():
    global chord_feat, chord_rec, beat_act, beat_trk
    if chord_feat is None:
        try:
            from madmom.features.chords import (
                CNNChordFeatureProcessor,
                CRFChordRecognitionProcessor,
            )
            from madmom.features.beats import (
                RNNBeatProcessor,
                DBNBeatTrackingProcessor,
            )
            chord_feat = CNNChordFeatureProcessor()
            chord_rec = CRFChordRecognitionProcessor()
            beat_act = RNNBeatProcessor()
            beat_trk = DBNBeatTrackingProcessor(fps=100)
        except ImportError as e:
            raise RuntimeError(f"madmom não está instalado no ambiente: {e}")

def to_cifra(label: str) -> str:
    """Converte anotação técnica do madmom (ex: 'C:maj', 'A:min', 'G:7') para Cifra padrão"""
    root, _, q = label.partition(":")
    mapping = {
        "maj": "",
        "min": "m",
        "7": "7",
        "min7": "m7",
        "maj7": "maj7",
        "dim": "dim",
        "aug": "aug",
        "sus4": "sus4",
        "sus2": "sus2",
    }
    return root + mapping.get(q, q)

@app.get("/health")
def health():
    return {"status": "ok", "cached_songs": len(CACHE)}

@app.get("/analyze/{video_id}")
def analyze(video_id: str):
    """
    Baixa o áudio do vídeo do YouTube via yt-dlp, converte para WAV (44.1kHz)
    e executa o modelo acústico madmom para detectar acordes e batidas em tempo real.
    """
    if video_id in CACHE:
        return CACHE[video_id]

    _init_models()

    with tempfile.TemporaryDirectory() as d:
        out_pattern = os.path.join(d, "audio.%(ext)s")
        # Baixa o melhor áudio e converte via ffmpeg para WAV mono 44.1kHz
        cmd = [
            "yt-dlp",
            "-x",
            "--audio-format", "wav",
            "--audio-quality", "0",
            "--postprocessor-args", "-ar 44100 -ac 1",
            "-o", out_pattern,
            f"https://www.youtube.com/watch?v={video_id}",
        ]
        
        proc = subprocess.run(cmd, capture_output=True, text=True)
        files = glob.glob(os.path.join(d, "audio.*"))
        if proc.returncode != 0 or not files:
            err_msg = proc.stderr.strip() if proc.stderr else "Falha ao baixar áudio com yt-dlp"
            raise HTTPException(status_code=502, detail=f"Erro ao obter áudio: {err_msg}")

        wav_path = files[0]

        # 1. Reconhecimento de acordes com CNN + CRF
        feats = chord_feat(wav_path)
        chords = chord_rec(feats)  # Retorna lista de tuplas (start, end, label)

        # 2. Rastreamento de batidas com RNN + DBN
        beat_activations = beat_act(wav_path)
        beats = beat_trk(beat_activations)

    # 3. Cálculo de BPM mediano
    bpm = 0
    if len(beats) > 2:
        diffs = np.diff(beats)
        median_diff = float(np.median(diffs))
        if median_diff > 0:
            bpm = round(60.0 / median_diff)

    formatted_chords = []
    for s, e, c in chords:
        if c != "N":  # Descarta trechos sem acorde
            formatted_chords.append({
                "start": round(float(s), 3),
                "end": round(float(e), 3),
                "chord": to_cifra(c),
            })

    data = {
        "videoId": video_id,
        "bpm": bpm if bpm > 0 else 80,
        "beats": [round(float(b), 3) for b in beats],
        "chords": formatted_chords,
    }

    CACHE[video_id] = data
    return data

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
