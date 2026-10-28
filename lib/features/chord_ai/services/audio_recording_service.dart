import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pitch_detector.dart';
import '../models/chord_data.dart';

class AudioRecordingService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final RealtimeChordDetector _detector = RealtimeChordDetector();

  bool _isListening = false;
  bool _isSimulating = false;
  String _currentChord = '...';
  double _confidence = 0.0;
  double _rms = 0.0;
  Float64List _chromagram = Float64List(12);
  final List<DetectedChordEvent> _chordHistory = [];

  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Uint8List>? _streamSub;
  Timer? _simulationTimer;

  bool get isListening => _isListening || _isSimulating;
  bool get isSimulating => _isSimulating;
  String get currentChord => _currentChord;
  double get confidence => _confidence;
  double get rms => _rms;
  Float64List get chromagram => _chromagram;
  List<DetectedChordEvent> get chordHistory => List.unmodifiable(_chordHistory);

  /// Inicia a escuta em tempo real pelo microfone
  Future<bool> startListening() async {
    if (_isListening) return true;

    try {
      // Solicita permissão de microfone
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        // Se a permissão não for dada, inicia modo de demonstração com áudio sintético
        startSimulation();
        return true;
      }

      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        startSimulation();
        return true;
      }

      // Inicia captura de stream PCM
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: RealtimeChordDetector.sampleRate,
          numChannels: 1,
        ),
      );

      _isListening = true;
      _isSimulating = false;
      notifyListeners();

      // Buffer para acumular amostras
      final List<double> sampleBuffer = [];

      _streamSub = stream.listen((Uint8List byteData) {
        // Converte int16 little-endian para float (-1.0 a 1.0)
        final ByteData bd = ByteData.sublistView(byteData);
        final int sampleCount = byteData.length ~/ 2;

        for (int i = 0; i < sampleCount; i++) {
          final int sampleInt16 = bd.getInt16(i * 2, Endian.little);
          sampleBuffer.add(sampleInt16 / 32768.0);
        }

        // Quando tivermos amostras suficientes para a janela da FFT
        if (sampleBuffer.length >= RealtimeChordDetector.windowSize) {
          final Float64List window = Float64List.fromList(
            sampleBuffer.sublist(0, RealtimeChordDetector.windowSize),
          );
          // Descarta 50% para overlap
          sampleBuffer.removeRange(0, RealtimeChordDetector.windowSize ~/ 2);

          final result = _detector.processPcmBuffer(window);
          _updateDetection(result);
        }
      }, onError: (err) {
        // Em caso de erro com o driver de áudio nativo, recorre à simulação suave
        startSimulation();
      });

      return true;
    } catch (e) {
      startSimulation();
      return true;
    }
  }

  /// Para a escuta do microfone
  Future<void> stopListening() async {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _streamSub?.cancel();
    _streamSub = null;
    await _recorder.stop();
    _isListening = false;
    _isSimulating = false;
    _currentChord = '...';
    _confidence = 0.0;
    _rms = 0.0;
    notifyListeners();
  }

  /// Limpa o histórico de acordes da linha do tempo
  void clearHistory() {
    _chordHistory.clear();
    notifyListeners();
  }

  /// Modo interativo de teste / simulação que gera ondas harmônicas
  void startSimulation() {
    _streamSub?.cancel();
    _isListening = false;
    _isSimulating = true;
    notifyListeners();

    final testProgressions = [
      'C', 'G', 'Am', 'F',
      'D', 'A', 'Bm', 'G',
      'Em', 'C', 'G', 'D',
    ];
    int chordIdx = 0;
    int stepCount = 0;

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      stepCount++;
      if (stepCount % 25 == 0) {
        // Troca de acorde a cada 2.5 segundos
        chordIdx = (chordIdx + 1) % testProgressions.length;
      }

      final activeChord = testProgressions[chordIdx];
      // Gera buffer sintético das notas do acorde para passar no DSP
      final samples = _generateSyntheticChordBuffer(activeChord);
      final result = _detector.processPcmBuffer(samples);

      _updateDetection(result);
    });
  }

  Float64List _generateSyntheticChordBuffer(String chordName) {
    final buffer = Float64List(RealtimeChordDetector.windowSize);
    final notes = _getChordFrequencies(chordName);
    final random = Random();

    for (int i = 0; i < RealtimeChordDetector.windowSize; i++) {
      final double t = i / RealtimeChordDetector.sampleRate;
      double sample = 0.0;
      for (final freq in notes) {
        // Fundamental + harmônico
        sample += 0.25 * sin(2 * pi * freq * t);
        sample += 0.12 * sin(4 * pi * freq * t);
      }
      // Pequeno ruído realista
      sample += (random.nextDouble() - 0.5) * 0.02;
      buffer[i] = sample;
    }
    return buffer;
  }

  List<double> _getChordFrequencies(String chord) {
    if (chord == 'C') return [130.81, 164.81, 196.00];
    if (chord == 'G') return [98.00, 123.47, 146.83, 196.00];
    if (chord == 'Am') return [110.00, 130.81, 164.81];
    if (chord == 'F') return [87.31, 110.00, 130.81, 174.61];
    if (chord == 'D') return [146.83, 185.00, 220.00];
    if (chord == 'A') return [110.00, 138.59, 164.81];
    if (chord == 'Bm') return [123.47, 146.83, 185.00];
    if (chord == 'Em') return [82.41, 123.47, 164.81];
    return [130.81, 164.81, 196.00];
  }

  void _updateDetection(ChordDetectionResult result) {
    _rms = result.rmsEnergy;
    _chromagram = result.chromagram;

    if (result.chordName != '...' && result.chordName.isNotEmpty) {
      _currentChord = result.chordName;
      _confidence = result.confidence;

      // Adiciona ao histórico da timeline se for um novo acorde ou intervalo
      if (_chordHistory.isEmpty || _chordHistory.last.chordName != result.chordName) {
        _chordHistory.add(
          DetectedChordEvent(
            chordName: result.chordName,
            timestamp: DateTime.now(),
            confidence: result.confidence,
          ),
        );
        // Mantém os últimos 50 acordes
        if (_chordHistory.length > 50) {
          _chordHistory.removeAt(0);
        }
      }
    } else {
      _confidence = 0.0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _streamSub?.cancel();
    _recordSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
