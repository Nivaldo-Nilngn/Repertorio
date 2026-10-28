# Chord backend

```bash
docker compose up --build -d
curl http://localhost:8000/health
curl -H "x-api-key: troque-por-uma-chave-forte" http://localhost:8000/analyze/dQw4w9WgXcQ
```

Flutter (emulador Android usa 10.0.2.2 em vez de localhost):

```bash
flutter run --dart-define=CHORD_API_URL=http://10.0.2.2:8000 \
            --dart-define=CHORD_API_KEY=troque-por-uma-chave-forte
```

Se o yt-dlp falhar com erro 403/"Sign in", atualize-o: `pip install -U yt-dlp`
(rebuild da imagem). O YouTube muda com frequência.
