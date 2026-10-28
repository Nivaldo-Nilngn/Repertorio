"""
Backend de análise de acordes (estilo Chordify).
GET /analyze/{video_id}  ->  {bpm, beats[], chords[{start,end,chord}], duration}
"""
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
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from madmom.features.beats import DBNBeatTrackingProcessor, RNNBeatProcessor
from madmom.features.chords import (CNNChordFeatureProcessor,
                                    CRFChordRecognitionProcessor)

API_KEY = os.getenv("API_KEY", "")                 # opcional: protege o endpoint
MAX_DURATION = int(os.getenv("MAX_DURATION", "2400"))  # segundos (40 min)
CACHE_DIR = Path(os.getenv("CACHE_DIR", "/data/cache"))
CACHE_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="Chord Analysis API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"],
                   allow_headers=["*"])

# Modelos carregados uma única vez
chord_feat = CNNChordFeatureProcessor()
chord_rec = CRFChordRecognitionProcessor()
beat_act = RNNBeatProcessor()
beat_trk = DBNBeatTrackingProcessor(fps=100)

# Análise é pesada: no máximo 2 ao mesmo tempo, e 1 por vídeo
_slots = threading.Semaphore(int(os.getenv("MAX_CONCURRENT", "2")))
_locks: dict[str, threading.Lock] = {}
_locks_guard = threading.Lock()

VIDEO_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")


def check_key(x_api_key: str = Header(default="")):
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(401, "Chave inválida")


def to_cifra(label: str) -> str:
    """madmom ('C:maj', 'A:min', 'G:7', 'D:min7') -> cifra ('C', 'Am', 'G7', 'Dm7')."""
    root, _, quality = label.partition(":")
    names = {"maj": "", "min": "m", "7": "7", "min7": "m7", "maj7": "maj7",
             "dim": "dim", "aug": "aug", "sus4": "sus4", "sus2": "sus2"}
    return root + names.get(quality, quality)


def download_audio(video_id: str, workdir: str) -> str:
    out = os.path.join(workdir, "audio.%(ext)s")
    cmd = [
        "yt-dlp",
        "--js-runtimes", "node:/usr/bin/node",
        "--no-playlist",
        "-x",
        "--audio-format", "wav",
        "--match-filter", f"duration < {MAX_DURATION}",
        "-o", out,
        f"https://www.youtube.com/watch?v={video_id}"
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=240)
    files = glob.glob(os.path.join(workdir, "audio.*"))
    if not files:
        err_msg = r.stderr.strip()
        if "does not pass filter" in (r.stdout + r.stderr):
            raise HTTPException(422, f"Vídeo excede o limite máximo de {MAX_DURATION // 60} minutos.")
        raise HTTPException(502, f"Falha ao obter áudio do YouTube: {err_msg[-250:] if err_msg else 'Formato não disponível'}")
    return files[0]


def compute_viterbi_bars(beats: list[float], chords: list[dict], duration: float, raw_bpm: int) -> tuple[int, str, list[dict]]:
    """Calcula compassos sincronizados com os tempos fortes da música (estilo Chord ai Forced-BPM Viterbi)."""
    # 1. Normaliza BPM (corrige oitavas de andamento)
    bpm = raw_bpm
    if bpm > 145:
        bpm = round(bpm / 2)
    elif bpm < 55 and bpm > 0:
        bpm = round(bpm * 2)
    if bpm <= 0:
        bpm = 80

    # 2. Alinhamento de compassos com os beats reais do detector de áudio
    bar_boundaries = []
    if len(beats) > 8:
        diffs = np.diff(beats)
        median_diff = float(np.median(diffs))
        beats_per_bar = 8 if median_diff < 0.52 else 4

        cur_idx = 0
        while cur_idx < len(beats):
            b_start = 0.0 if cur_idx == 0 else beats[cur_idx]
            next_idx = cur_idx + beats_per_bar
            b_end = beats[next_idx] if next_idx < len(beats) else duration
            bar_boundaries.append((round(b_start, 2), round(b_end, 2)))
            cur_idx = next_idx
    else:
        bar_duration = (60.0 / bpm) * 4.0
        total_bars = max(1, int(np.ceil(duration / bar_duration)))
        for i in range(total_bars):
            s = i * bar_duration
            e = min(duration, (i + 1) * bar_duration)
            bar_boundaries.append((round(s, 2), round(e, 2)))

    # 3. Decodificação harmônica com inércia de transição
    bars = []
    current_chord = chords[0]["chord"] if chords else "C"
    chord_histogram = {}

    for i, (b_start, b_end) in enumerate(bar_boundaries):
        dur = b_end - b_start
        if dur <= 0.1:
            continue

        durations = {}
        for c in chords:
            cs = c["start"]
            ce = c["end"]
            overlap = max(0.0, min(ce, b_end) - max(cs, b_start))
            if overlap > 0:
                ch = c["chord"]
                durations[ch] = durations.get(ch, 0.0) + overlap

        best_chord = current_chord
        max_overlap = 0.0
        for ch, ov in durations.items():
            if ov > max_overlap:
                max_overlap = ov
                best_chord = ch

        # Inércia harmônica: só altera se tiver presença expressiva no compasso (mínimo 28%)
        if max_overlap >= dur * 0.28:
            current_chord = best_chord

        chord_histogram[current_chord] = chord_histogram.get(current_chord, 0.0) + dur
        bars.append({
            "number": len(bars) + 1,
            "start": b_start,
            "end": b_end,
            "duration": round(dur, 2),
            "chord": current_chord
        })

    # 4. Estimação de Tom (Key) pela tônica harmônica mais sustentada
    detected_key = "C"
    if chord_histogram:
        detected_key = max(chord_histogram.items(), key=lambda x: x[1])[0]

    return bpm, detected_key, bars


def analyze_file(wav: str) -> dict:
    chords = chord_rec(chord_feat(wav))      # [(inicio, fim, rotulo)]
    beats = beat_trk(beat_act(wav))
    raw_bpm = 0
    if len(beats) > 2:
        raw_bpm = round(60 / float(np.median(np.diff(beats))))
    segs = [{"start": round(float(s), 3), "end": round(float(e), 3),
             "chord": to_cifra(c)} for s, e, c in chords if c != "N"]
    duration = float(chords[-1][1]) if len(chords) else 0.0
    beats_list = [round(float(b), 3) for b in beats]

    bpm, detected_key, bars = compute_viterbi_bars(beats_list, segs, duration, raw_bpm)

    return {
        "bpm": bpm,
        "key": detected_key,
        "raw_bpm": raw_bpm,
        "beats": beats_list,
        "chords": segs,
        "bars": bars,
        "duration": round(duration, 2)
    }


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/analyze/{video_id}", dependencies=[Depends(check_key)])
def analyze(video_id: str):
    if not VIDEO_ID_RE.match(video_id):
        raise HTTPException(400, "videoId inválido")

    cache_file = CACHE_DIR / f"{video_id}.json"
    if cache_file.exists():
        data = json.loads(cache_file.read_text())
        # Atualiza automaticamente o cache legado com os compassos Viterbi
        if "bars" not in data or not data["bars"]:
            bpm, key, bars = compute_viterbi_bars(
                data.get("beats", []),
                data.get("chords", []),
                float(data.get("duration", 0)),
                int(data.get("bpm", 80))
            )
            data["bpm"] = bpm
            data["key"] = key
            data["bars"] = bars
            cache_file.write_text(json.dumps(data))
        return data

    with _locks_guard:
        lock = _locks.setdefault(video_id, threading.Lock())
    with lock:                                   # evita analisar o mesmo vídeo 2x
        if cache_file.exists():
            return json.loads(cache_file.read_text())
        with _slots:
            mp3_cache = CACHE_DIR / f"{video_id}.mp3"
            if mp3_cache.exists() and mp3_cache.stat().st_size > 0:
                with tempfile.TemporaryDirectory() as d:
                    wav = os.path.join(d, "audio.wav")
                    subprocess.run(["ffmpeg", "-y", "-i", str(mp3_cache), wav], capture_output=True, timeout=60)
                    data = analyze_file(wav)
            else:
                with tempfile.TemporaryDirectory() as d:
                    wav = download_audio(video_id, d)
                    data = analyze_file(wav)
                    # Salva áudio em MP3 no cache para streaming contínuo no Jam Player
                    if not mp3_cache.exists():
                        try:
                            subprocess.run(
                                ["ffmpeg", "-y", "-i", wav, "-b:a", "192k", str(mp3_cache)],
                                capture_output=True,
                                timeout=45
                            )
                        except Exception as err:
                            print(f"[AUDIO CONVERT ERROR] {err}")
        if not data["chords"]:
            raise HTTPException(422, "Nenhum acorde detectado")
        cache_file.write_text(json.dumps(data))
        return data


def ensure_audio(video_id: str) -> Path:
    """Garante que o arquivo de áudio existe no cache em MP3 ou formato original para streaming."""
    for ext in ["mp3", "m4a", "webm", "wav", "ogg"]:
        p = CACHE_DIR / f"{video_id}.{ext}"
        if p.exists() and p.stat().st_size > 0:
            return p

    # Se não existir, baixa diretamente via yt-dlp em MP3
    out = str(CACHE_DIR / f"{video_id}.%(ext)s")
    cmd = [
        "yt-dlp",
        "--js-runtimes", "node:/usr/bin/node",
        "--no-playlist",
        "-x",
        "--audio-format", "mp3",
        "--match-filter", f"duration < {MAX_DURATION}",
        "-o", out,
        f"https://www.youtube.com/watch?v={video_id}"
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=240)
    for ext in ["mp3", "m4a", "webm", "wav", "ogg"]:
        p = CACHE_DIR / f"{video_id}.{ext}"
        if p.exists() and p.stat().st_size > 0:
            return p
    raise HTTPException(502, f"Falha ao obter áudio do YouTube: {r.stderr[-200:] if r.stderr else 'Erro ao extrair áudio'}")


@app.get("/audio/{video_id}")
def get_audio(video_id: str):
    """Endpoint de streaming de áudio nativo para o Jam Player (zero CORS, suporte a ranges)."""
    if not VIDEO_ID_RE.match(video_id):
        raise HTTPException(400, "videoId inválido")
    audio_path = ensure_audio(video_id)
    media_type = "audio/mpeg" if audio_path.suffix == ".mp3" else "audio/wav"
    return FileResponse(
        str(audio_path),
        media_type=media_type,
        headers={"Accept-Ranges": "bytes"}
    )


@app.get("/search")
def search_youtube(q: str):
    query = q.strip()
    if not query:
        return []

    cmd = [
        "yt-dlp",
        "--flat-playlist",
        "--no-warnings",
        "--print", "%(id)s;%(title)s;%(uploader)s;%(duration)s",
        f"ytsearch10:{query}"
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        lines = proc.stdout.strip().split("\n")
        results = []
        for line in lines:
            line = line.strip()
            if not line or ";" not in line:
                continue
            parts = line.split(";")
            if len(parts) >= 2:
                video_id = parts[0].strip()
                title = parts[1].strip()
                uploader = parts[2].strip() if len(parts) > 2 else "YouTube"
                dur_raw = parts[3].strip() if len(parts) > 3 else "0"
                try:
                    dur_sec = int(float(dur_raw))
                except Exception:
                    dur_sec = 0

                m = dur_sec // 60
                s = dur_sec % 60
                duration_str = f"{m:02d}:{s:02d}"

                if len(video_id) == 11:
                    results.append({
                        "id": video_id,
                        "title": title,
                        "author": uploader,
                        "duration": duration_str,
                        "thumbnailUrl": f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"
                    })
        return results
    except Exception as e:
        print(f"[SEARCH ERROR] {e}")
        return []

