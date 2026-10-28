import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'setlist_repository.dart';
import '../widgets/scrolling_waveform_timeline.dart';

class AiAnalysisResult {
  final FeaturedSong song;
  final String key;
  final int bpm;
  final List<String> chords;
  final String provider;
  final String summary;

  const AiAnalysisResult({
    required this.song,
    required this.key,
    required this.bpm,
    required this.chords,
    required this.provider,
    required this.summary,
  });
}

class ChordAnalysisException implements Exception {
  final String message;
  ChordAnalysisException(this.message);
  @override
  String toString() => message;
}

/// Lê os acordes a partir do ÁUDIO do vídeo (via backend), como o Chordify.
class AiChordAnalysisService {
  static final AiChordAnalysisService _instance = AiChordAnalysisService._();
  factory AiChordAnalysisService() => _instance;
  AiChordAnalysisService._();

  static String get _baseUrl {
    const fromEnv = String.fromEnvironment('CHORD_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static const String _apiKey =
      String.fromEnvironment('CHORD_API_KEY', defaultValue: '');

  Future<AiAnalysisResult> analyzeSong({
    required String title,
    required String artist,
    required String videoId,
    int durationSeconds = 240,
    int? referenceBpm,
    String? referenceKey,
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.10, 'Baixando o áudio do vídeo...');

    // Progresso "otimista" enquanto o servidor trabalha (20-60s na 1ª vez)
    double p = 0.10;
    final ticker = Timer.periodic(const Duration(milliseconds: 800), (_) {
      p = (p + 0.02).clamp(0.10, 0.85);
      onProgress?.call(p, 'Analisando acordes e batidas...');
    });

    late final http.Response res;
    try {
      res = await http.get(
        Uri.parse('$_baseUrl/analyze/$videoId'),
        headers: {if (_apiKey.isNotEmpty) 'x-api-key': _apiKey},
      ).timeout(const Duration(minutes: 3));
    } on TimeoutException {
      throw ChordAnalysisException('O servidor demorou demais para responder.');
    } catch (e) {
      throw ChordAnalysisException('Não foi possível conectar ao servidor ($e).');
    } finally {
      ticker.cancel();
    }

    if (res.statusCode != 200) {
      String detail = '';
      try {
        detail = (json.decode(utf8.decode(res.bodyBytes))['detail'] ?? '').toString();
      } catch (_) {}
      throw ChordAnalysisException(
          'Falha na análise (HTTP ${res.statusCode}) $detail'.trim());
    }

    onProgress?.call(0.92, 'Montando a cifra e compassos...');
    final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    final rawSegments = <(double, double, String)>[];

    for (final c in (data['chords'] as List)) {
      final start = (c['start'] as num).toDouble();
      final end = (c['end'] as num).toDouble();
      final chord = (c['chord'] as String).trim();
      if (chord.isNotEmpty && chord != 'N') {
        rawSegments.add((start, end, chord));
      }
    }
    if (rawSegments.isEmpty) {
      throw ChordAnalysisException('Nenhum acorde foi detectado neste áudio.');
    }

    // Calibra o BPM: se houver BPM de referência oficial (ex: 68 BPM), utiliza ele.
    // Caso contrário, normaliza o BPM do detector de áudio para semínimas (45 a 160 BPM).
    int rawBpm = (data['bpm'] as num?)?.toInt() ?? 0;
    int bpm = 80;

    if (referenceBpm != null && referenceBpm >= 45 && referenceBpm <= 220) {
      bpm = referenceBpm;
    } else if (rawBpm > 0) {
      if (rawBpm > 150) {
        rawBpm = (rawBpm / 2).round();
      } else if (rawBpm < 55 && rawBpm > 0) {
        rawBpm = rawBpm * 2;
      }
      bpm = (rawBpm >= 45 && rawBpm <= 220) ? rawBpm : 80;
    }

    final dur = ((data['duration'] as num?)?.toInt() ?? 0) > 0
        ? (data['duration'] as num).toInt()
        : durationSeconds;

    // Monta compassos no estilo Chord ai (Forced-BPM Viterbi Decodification)
    final measures = <MeasureBeat>[];

    if (data['bars'] is List && (data['bars'] as List).isNotEmpty) {
      // 1. Usa os compassos sincronizados calculados pelo backend com Forced-BPM
      for (final b in (data['bars'] as List)) {
        final barNum = (b['number'] as num?)?.toInt() ?? (measures.length + 1);
        final start = (b['start'] as num?)?.toDouble() ?? 0.0;
        final end = (b['end'] as num?)?.toDouble() ?? (start + 3.0);
        final chord = (b['chord'] as String?)?.trim() ?? 'C';
        measures.add(MeasureBeat(
          measureNumber: barNum,
          startSeconds: start,
          durationSeconds: (end - start).clamp(0.2, 30.0),
          chord: chord,
        ));
      }
    } else {
      // 2. Fallback inteligente com quantização de beats e inércia harmônica no cliente
      final rawBeats = <double>[];
      if (data['beats'] is List) {
        for (final b in (data['beats'] as List)) {
          if (b is num && b > 0) rawBeats.add(b.toDouble());
        }
        rawBeats.sort();
      }

      final barBoundaries = <(double, double)>[];
      if (rawBeats.length > 8) {
        final diffs = <double>[];
        for (int i = 1; i < rawBeats.length; i++) {
          final d = rawBeats[i] - rawBeats[i - 1];
          if (d > 0.1 && d < 2.5) diffs.add(d);
        }
        diffs.sort();
        final medianDiff = diffs.isNotEmpty ? diffs[diffs.length ~/ 2] : 0.75;
        final beatsPerBar = medianDiff < 0.52 ? 8 : 4;

        var curIdx = 0;
        while (curIdx < rawBeats.length) {
          final bStart = curIdx == 0 ? 0.0 : rawBeats[curIdx];
          final nextIdx = curIdx + beatsPerBar;
          final bEnd = nextIdx < rawBeats.length ? rawBeats[nextIdx] : dur.toDouble();
          barBoundaries.add((bStart, bEnd));
          curIdx = nextIdx;
        }
      } else {
        final double beatDuration = 60.0 / bpm;
        final double barDuration = beatDuration * 4.0;
        final int totalBars = (dur / barDuration).ceil().clamp(1, 2000);
        for (int i = 0; i < totalBars; i++) {
          final startSec = i * barDuration;
          final endSec = ((i + 1) * barDuration).clamp(0.0, dur.toDouble());
          barBoundaries.add((startSec, endSec));
        }
      }

      String currentChord = rawSegments.isNotEmpty ? rawSegments.first.$3 : (referenceKey ?? 'C');
      for (int i = 0; i < barBoundaries.length; i++) {
        final (startSec, endSec) = barBoundaries[i];
        final measureDur = endSec - startSec;
        if (measureDur <= 0.05) continue;

        final chordDurations = <String, double>{};
        for (final seg in rawSegments) {
          final overlap = (seg.$2 < endSec ? seg.$2 : endSec) -
              (seg.$1 > startSec ? seg.$1 : startSec);
          if (overlap > 0) {
            chordDurations[seg.$3] = (chordDurations[seg.$3] ?? 0.0) + overlap;
          }
        }

        String bestChord = currentChord;
        double maxDur = 0.0;
        for (final entry in chordDurations.entries) {
          if (entry.value > maxDur) {
            maxDur = entry.value;
            bestChord = entry.key;
          }
        }

        // Inércia harmônica: só altera se tiver presença expressiva no compasso (mínimo 28%)
        if (maxDur >= measureDur * 0.28) {
          currentChord = bestChord;
        }

        measures.add(MeasureBeat(
          measureNumber: i + 1,
          startSeconds: startSec,
          durationSeconds: measureDur,
          chord: currentChord,
        ));
      }
    }

    // Gera marcadores de acordes alinhados aos compassos reais
    final markers = <ChordMarker>[];
    String lastChord = '';
    for (final m in measures) {
      if (m.chord != lastChord) {
        markers.add(ChordMarker(m.startSeconds, m.chord));
        lastChord = m.chord;
      }
    }

    final backendKey = (data['key'] as String?)?.trim();
    final detectedKey = (backendKey != null && backendKey.isNotEmpty)
        ? backendKey
        : estimateKeyFromChords(
            measures.map((m) => m.chord).toList(),
            measures.map((m) => m.durationSeconds).toList(),
          );
    final key = (referenceKey != null && referenceKey.isNotEmpty)
        ? referenceKey
        : detectedKey;

    final song = FeaturedSong(
      id: videoId,
      title: title,
      artist: artist,
      categoryId: 'ai_analyzed',
      key: key,
      bpm: bpm,
      durationSeconds: dur,
      thumbnailUrl: videoId.startsWith('local_')
          ? ''
          : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      jamsCount: 'Analisado pelo áudio',
      chordMarkers: markers.isNotEmpty
          ? markers
          : [ChordMarker(0, measures.isNotEmpty ? measures.first.chord : 'C')],
      measures: measures,
    );

    onProgress?.call(1.0, 'Análise harmônica concluída com sucesso!');

    return AiAnalysisResult(
      song: song,
      key: key,
      bpm: bpm,
      chords: measures.map((m) => m.chord).toSet().toList(),
      provider: 'Análise de áudio',
      summary: 'Tom $key • $bpm BPM • ${measures.length} compassos sincronizados.',
    );
  }

  // ---------------------------------------------------------------- tom ----

  static const _namesSharp = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  static const _majorKeys = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'
  ];
  static const _minorKeys = [
    'Cm', 'C#m', 'Dm', 'Ebm', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'Bbm', 'Bm'
  ];
  static const _flatToSharp = {
    'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#'
  };

  /// Graus diatônicos da escala maior (1, 2m, 3m, 4, 5, 6m)
  static const _major = [
    (0, false), (2, true), (4, true), (5, false), (7, false), (9, true)
  ];

  /// Graus diatônicos da escala menor natural e harmônica
  static const _minor = [
    (0, true), (2, false), (3, false), (5, true), (7, true), (7, false), (8, false), (10, false)
  ];

  /// Estima o tom da música a partir da sequência de acordes e suas durações
  static String estimateKeyFromChords(
    List<String> chords, [
    List<double>? durations,
  ]) {
    final re = RegExp(r'^([A-G][#b]?)(m(?!aj))?');
    final parsed = <(int, bool, double)>[];

    for (var i = 0; i < chords.length; i++) {
      final chord = chords[i].trim();
      final m = re.firstMatch(chord);
      if (m == null) continue;
      var root = m.group(1)!;
      root = _flatToSharp[root] ?? root;
      final idx = _namesSharp.indexOf(root);
      if (idx < 0) continue;
      final isMinor = m.group(2) != null;
      final dur = (durations != null && i < durations.length) ? durations[i] : 4.0;
      parsed.add((idx, isMinor, dur));
    }
    if (parsed.isEmpty) return 'C';

    var bestScore = -1.0;
    var bestKey = 'C';

    for (var tonic = 0; tonic < 12; tonic++) {
      for (final isMinorKey in [false, true]) {
        final degrees = isMinorKey ? _minor : _major;
        var score = 0.0;

        for (final (root, isMinor, dur) in parsed) {
          // Correção essencial: módulo estritamente positivo em Dart/JS
          final rel = ((root - tonic) % 12 + 12) % 12;
          if (degrees.any((d) => d.$1 == rel && d.$2 == isMinor)) {
            score += dur;
            if (rel == 0) score += dur * 0.6; // bônus para a tônica
          }
        }

        final first = parsed.first;
        final last = parsed.last;
        // O primeiro e o último acordes frequentemente definem ou resolvem na tônica
        if (first.$1 == tonic && first.$2 == isMinorKey) score += 15.0;
        if (last.$1 == tonic && last.$2 == isMinorKey) score += 10.0;

        if (score > bestScore) {
          bestScore = score;
          bestKey = isMinorKey ? _minorKeys[tonic] : _majorKeys[tonic];
        }
      }
    }
    return bestKey;
  }
}
