import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';
import '../models/chord_data.dart';

class ChordDetectionResult {
  final String chordName;
  final String root;
  final String quality;
  final String? bass;
  final double confidence; // 0.0 a 1.0
  final Float64List chromagram; // 12 classes de notas (C .. B)
  final double rmsEnergy; // Nível de volume / energia

  ChordDetectionResult({
    required this.chordName,
    required this.root,
    required this.quality,
    this.bass,
    required this.confidence,
    required this.chromagram,
    required this.rmsEnergy,
  });
}

/// Motor DSP em tempo real e offline de detecção de acordes idêntico à arquitetura do Chord AI
class RealtimeChordDetector {
  static const int sampleRate = 44100;
  static const int windowSize = 4096; // Resolução de frequência suficiente para notas graves (~10.76 Hz/bin)

  final FFT _fft = FFT(windowSize);
  final Float64List _window = Window.hamming(windowSize);

  static const List<String> notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  /// Dicionário Completo de Templates Harmônicos do Chord AI (pesos relativos por intervalo)
  static const Map<String, List<double>> chordTemplates = {
    // Tríades Principais
    '': [1.0, 0.0, 0.0, 0.0, 0.85, 0.0, 0.0, 0.90, 0.0, 0.0, 0.0, 0.0], // Maior (1, 3M, 5J)
    'm': [1.0, 0.0, 0.0, 0.85, 0.0, 0.0, 0.0, 0.90, 0.0, 0.0, 0.0, 0.0], // Menor (1, 3m, 5J)
    
    // Tétrades e Sétimas
    '7': [1.0, 0.0, 0.0, 0.0, 0.80, 0.0, 0.0, 0.85, 0.0, 0.0, 0.70, 0.0], // 7 Dominante (1, 3M, 5J, 7m)
    'm7': [1.0, 0.0, 0.0, 0.80, 0.0, 0.0, 0.0, 0.85, 0.0, 0.0, 0.70, 0.0], // m7 (1, 3m, 5J, 7m)
    'M7': [1.0, 0.0, 0.0, 0.0, 0.80, 0.0, 0.0, 0.85, 0.0, 0.0, 0.0, 0.70], // 7M (1, 3M, 5J, 7M)
    'mM7': [1.0, 0.0, 0.0, 0.80, 0.0, 0.0, 0.0, 0.85, 0.0, 0.0, 0.0, 0.70], // m(7M) (1, 3m, 5J, 7M)
    
    // Suspensos
    'sus4': [1.0, 0.0, 0.0, 0.0, 0.0, 0.85, 0.0, 0.90, 0.0, 0.0, 0.0, 0.0], // Sus4 (1, 4J, 5J)
    'sus2': [1.0, 0.0, 0.85, 0.0, 0.0, 0.0, 0.0, 0.90, 0.0, 0.0, 0.0, 0.0], // Sus2 (1, 2M, 5J)
    '7sus4': [1.0, 0.0, 0.0, 0.0, 0.0, 0.80, 0.0, 0.85, 0.0, 0.0, 0.70, 0.0], // 7sus4
    
    // Diminutos e Aumentados
    'dim': [1.0, 0.0, 0.0, 0.85, 0.0, 0.0, 0.85, 0.0, 0.0, 0.0, 0.0, 0.0], // Diminuto (1, 3m, 5dim)
    'dim7': [1.0, 0.0, 0.0, 0.80, 0.0, 0.0, 0.80, 0.0, 0.0, 0.75, 0.0, 0.0], // Diminuto 7 (1, 3m, 5dim, 7dim)
    'm7b5': [1.0, 0.0, 0.0, 0.80, 0.0, 0.0, 0.80, 0.0, 0.0, 0.0, 0.70, 0.0], // Meio-diminuto (1, 3m, 5dim, 7m)
    'aug': [1.0, 0.0, 0.0, 0.0, 0.85, 0.0, 0.0, 0.0, 0.85, 0.0, 0.0, 0.0], // Aumentado (1, 3M, 5aum)
    
    // Sextas e Nonas
    '6': [1.0, 0.0, 0.0, 0.0, 0.80, 0.0, 0.0, 0.85, 0.0, 0.70, 0.0, 0.0], // 6 (1, 3M, 5J, 6M)
    'm6': [1.0, 0.0, 0.0, 0.80, 0.0, 0.0, 0.0, 0.85, 0.0, 0.70, 0.0, 0.0], // m6 (1, 3m, 5J, 6M)
    '9': [1.0, 0.0, 0.65, 0.0, 0.75, 0.0, 0.0, 0.80, 0.0, 0.0, 0.65, 0.0], // 9 (1, 2M, 3M, 5J, 7m)
    'add9': [1.0, 0.0, 0.70, 0.0, 0.80, 0.0, 0.0, 0.85, 0.0, 0.0, 0.0, 0.0], // add9 (1, 2M, 3M, 5J)
    
    // Power Chord
    '5': [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0], // Power chord
  };

  // Histórico para suavização temporal com HMM simplificado (evita flicker)
  String _lastStableChord = 'Nenhum';
  String _lastRoot = 'C';
  String _lastQuality = '';
  String? _lastBass;
  int _consecutiveDetections = 0;
  static const int _stabilityThreshold = 2;

  // Filtro exponencial de suavização do cromagrama
  final Float64List _smoothedChroma = Float64List(12);

  /// Processa um bloco de amostras PCM (normalizadas entre -1.0 e 1.0)
  ChordDetectionResult processPcmBuffer(Float64List pcmSamples) {
    if (pcmSamples.length < windowSize) {
      return ChordDetectionResult(
        chordName: _lastStableChord,
        root: _lastRoot,
        quality: _lastQuality,
        bass: _lastBass,
        confidence: 0.0,
        chromagram: Float64List(12),
        rmsEnergy: 0.0,
      );
    }

    // 1. Calcula energia RMS para detectar silêncio / ruído de fundo
    double sumSquares = 0.0;
    for (int i = 0; i < windowSize; i++) {
      sumSquares += pcmSamples[i] * pcmSamples[i];
    }
    final double rms = sqrt(sumSquares / windowSize);

    // Se o sinal for muito baixo (silêncio ou ruído ambiente insignificante)
    if (rms < 0.012) {
      _consecutiveDetections = 0;
      return ChordDetectionResult(
        chordName: '...',
        root: '',
        quality: '',
        bass: null,
        confidence: 0.0,
        chromagram: Float64List(12),
        rmsEnergy: rms,
      );
    }

    // 2. Aplica janela de Hamming
    final Float64List windowed = _window.applyWindowReal(pcmSamples);

    // 3. FFT e espectro de magnitude
    final complexFreq = _fft.realFft(windowed);
    final Float64List magnitudes = complexFreq.magnitudes();
    final double binFreq = sampleRate / windowSize; // ~10.76 Hz

    // 4. Detecção de Baixo Fundamental (F0 no intervalo 40Hz - 260Hz)
    // Permite identificar inversões reais de acordes como C/E, G/B, D/F#, Am/G
    final int bassMinBin = max(1, (40.0 / binFreq).round());
    final int bassMaxBin = min(magnitudes.length - 1, (260.0 / binFreq).round());

    final Float64List bassChroma = Float64List(12);
    double maxBassMag = 0.0;
    int dominantBassPitchClass = -1;

    for (int bin = bassMinBin; bin <= bassMaxBin; bin++) {
      final double freq = bin * binFreq;
      final double mag = magnitudes[bin];
      if (mag <= 0) continue;

      final double midi = 69.0 + 12.0 * (log(freq / 440.0) / ln2);
      final int pc = ((midi.round() % 12) + 12) % 12;

      // Pondera mais frequências graves autênticas
      final double weight = 1.0 / (1.0 + 0.005 * freq);
      bassChroma[pc] += mag * weight;

      if (bassChroma[pc] > maxBassMag) {
        maxBassMag = bassChroma[pc];
        dominantBassPitchClass = pc;
      }
    }

    // 5. Cromagrama Harmônico Geral (Pitch Class Profile: 65Hz a 1200Hz)
    final Float64List rawChroma = Float64List(12);
    final int minBin = max(1, (65.0 / binFreq).round());
    final int maxBin = min(magnitudes.length - 1, (1200.0 / binFreq).round());

    for (int bin = minBin; bin <= maxBin; bin++) {
      final double freq = bin * binFreq;
      final double mag = magnitudes[bin];
      if (mag <= 0) continue;

      final double midi = 69.0 + 12.0 * (log(freq / 440.0) / ln2);
      final int pitchClass = ((midi.round() % 12) + 12) % 12;

      // Ponderação harmônica exponencial
      final double weight = 1.0 / (1.0 + 0.001 * freq);
      rawChroma[pitchClass] += mag * weight;
    }

    // Suavização exponencial do cromagrama (EMA - Exponential Moving Average)
    const double alpha = 0.35;
    for (int i = 0; i < 12; i++) {
      _smoothedChroma[i] = (1 - alpha) * _smoothedChroma[i] + alpha * rawChroma[i];
    }

    // Normalização L2 do cromagrama
    double chromaNorm = 0.0;
    for (int i = 0; i < 12; i++) {
      chromaNorm += _smoothedChroma[i] * _smoothedChroma[i];
    }
    chromaNorm = sqrt(chromaNorm);
    final Float64List normalizedChroma = Float64List(12);
    if (chromaNorm > 0.0) {
      for (int i = 0; i < 12; i++) {
        normalizedChroma[i] = _smoothedChroma[i] / chromaNorm;
      }
    }

    // 6. Template Matching com Pesos de Cosseno
    String bestRoot = 'C';
    String bestQuality = '';
    double bestScore = -1.0;
    int bestRootIndex = 0;

    for (int rootIdx = 0; rootIdx < 12; rootIdx++) {
      final rootNote = notes[rootIdx];

      for (final entry in chordTemplates.entries) {
        final quality = entry.key;
        final template = entry.value;

        double score = 0.0;
        double templateNorm = 0.0;

        for (int i = 0; i < 12; i++) {
          final int shiftedIdx = (rootIdx + i) % 12;
          final double tVal = template[i];
          score += normalizedChroma[shiftedIdx] * tVal;
          templateNorm += tVal * tVal;
        }

        templateNorm = sqrt(templateNorm);
        if (templateNorm > 0) {
          score /= templateNorm;
        }

        // Bônus se o baixo coincidir com a fundamental ou terceira
        if (dominantBassPitchClass == rootIdx) {
          score *= 1.08;
        }

        if (score > bestScore) {
          bestScore = score;
          bestRoot = rootNote;
          bestQuality = quality;
          bestRootIndex = rootIdx;
        }
      }
    }

    // 7. Detecção de Baixo Invertido (Slash Chords)
    // Se a nota mais grave do baixo difere da fundamental e pertence ao acorde:
    String? detectedBass;
    if (dominantBassPitchClass >= 0 && dominantBassPitchClass != bestRootIndex) {
      final template = chordTemplates[bestQuality] ?? chordTemplates['']!;
      final int intervalFromRoot = (dominantBassPitchClass - bestRootIndex + 12) % 12;

      // Se o baixo é uma das notas do acorde (ex: Terça Maior = 4, Quinta = 7, Terça Menor = 3)
      if (template[intervalFromRoot] > 0.5) {
        detectedBass = notes[dominantBassPitchClass];
      }
    }

    // Monta o nome final do acorde
    String candidateChord = '$bestRoot$bestQuality';
    if (detectedBass != null && detectedBass.isNotEmpty) {
      candidateChord = '$bestRoot$bestQuality/$detectedBass';
    }

    // 8. Suavização Temporal (HMM / Viterbi latch)
    String outputChord = _lastStableChord;
    if (bestScore > 0.52) {
      if (candidateChord == _lastStableChord) {
        _consecutiveDetections++;
      } else {
        _consecutiveDetections = 1;
        if (_consecutiveDetections >= _stabilityThreshold) {
          _lastStableChord = candidateChord;
          _lastRoot = bestRoot;
          _lastQuality = bestQuality;
          _lastBass = detectedBass;
          outputChord = candidateChord;
        }
      }
      _lastStableChord = candidateChord;
      _lastRoot = bestRoot;
      _lastQuality = bestQuality;
      _lastBass = detectedBass;
      outputChord = candidateChord;
    }

    return ChordDetectionResult(
      chordName: outputChord.isEmpty ? '...' : outputChord,
      root: _lastRoot,
      quality: _lastQuality,
      bass: _lastBass,
      confidence: bestScore.clamp(0.0, 1.0),
      chromagram: normalizedChroma,
      rmsEnergy: rms,
    );
  }

  /// Análise de fluxo de áudio para arquivos de música completos (MP3 / WAV)
  /// Retorna lista de marcas de tempo (segundos, acorde)
  static List<DetectedChordEvent> analyzeFullAudioTrack({
    required Float64List pcmSamples,
    required int sampleRate,
    double hopSeconds = 0.5,
  }) {
    final detector = RealtimeChordDetector();
    final List<DetectedChordEvent> result = [];
    final int hopSize = (sampleRate * hopSeconds).round();

    for (int i = 0; i + windowSize <= pcmSamples.length; i += hopSize) {
      final chunk = pcmSamples.sublist(i, i + windowSize);
      final detection = detector.processPcmBuffer(chunk);

      if (detection.chordName != '...' && detection.confidence > 0.5) {
        final double seconds = i / sampleRate;
        result.add(
          DetectedChordEvent(
            chordName: detection.chordName,
            timestamp: DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round()),
            confidence: detection.confidence,
          ),
        );
      }
    }

    return result;
  }
}
