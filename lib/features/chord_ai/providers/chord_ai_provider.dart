import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/detected_chord.dart';
import '../services/audio_capture_service.dart';
import '../services/chord_matcher.dart';
import '../services/fft_analyzer.dart';

final chordAiProvider = NotifierProvider<ChordAiNotifier, ChordAiState>(() {
  return ChordAiNotifier();
});

class ChordAiNotifier extends Notifier<ChordAiState> {
  final AudioCaptureService _audioCapture = AudioCaptureService();

  // Smoothing buffers
  final List<String> _recentDetections = [];
  String? _lastStableChord;
  DateTime? _lastChordTime;

  @override
  ChordAiState build() {
    ref.onDispose(() {
      _audioCapture.stop();
    });
    return const ChordAiState();
  }

  Future<bool> startListening() async {
    if (state.isListening) return true;

    state = state.copyWith(
      isListening: true,
      statusMessage: 'Escutando microfone...',
    );

    final success = await _audioCapture.start((
        {required magnitudes,
        required sampleRate,
        required fftSize,
        required audioLevel}) {
      _processAudioFrame(
        magnitudes: magnitudes,
        sampleRate: sampleRate,
        fftSize: fftSize,
        audioLevel: audioLevel,
      );
    });

    if (!success) {
      state = state.copyWith(
        isListening: false,
        statusMessage: 'Falha ao acessar o microfone. Verifique as permissões.',
      );
      return false;
    }

    return true;
  }

  void stopListening() {
    _audioCapture.stop();
    _recentDetections.clear();
    state = state.copyWith(
      isListening: false,
      isRecording: false,
      clearCurrentChord: true,
      audioLevel: 0.0,
      chromagram: List.filled(12, 0.0),
      statusMessage: 'Detecção pausada.',
    );
  }

  void toggleListening() {
    if (state.isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void startRecording() {
    if (!state.isListening) {
      startListening();
    }
    state = state.copyWith(
      isRecording: true,
      statusMessage: 'Gravando progressão de acordes...',
    );
  }

  void stopRecording() {
    state = state.copyWith(
      isRecording: false,
      statusMessage: state.recordedChords.isNotEmpty
          ? '${state.recordedChords.length} acordes gravados.'
          : 'Gravação parada.',
    );
  }

  void toggleRecording() {
    if (state.isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  }

  void clearRecordedChords() {
    state = state.copyWith(
      recordedChords: [],
      estimatedKey: null,
      statusMessage: 'Histórico de gravação limpo.',
    );
  }

  void removeChordAt(int index) {
    if (index < 0 || index >= state.recordedChords.length) return;
    final updated = List<RecordedChordItem>.from(state.recordedChords)..removeAt(index);
    final key = updated.isNotEmpty
        ? ChordMatcher.estimateKey(updated.map((c) => c.chord).toList())
        : null;

    state = state.copyWith(
      recordedChords: updated,
      estimatedKey: key,
    );
  }

  void setInstrument(String instrument) {
    state = state.copyWith(instrument: instrument);
  }

  void _processAudioFrame({
    required List<double> magnitudes,
    required double sampleRate,
    required int fftSize,
    required double audioLevel,
  }) {
    // 1. Compute Chromagram
    final chroma = FftAnalyzer.computeChromagram(
      magnitudes: magnitudes,
      sampleRate: sampleRate,
      fftSize: fftSize,
    );

    // 2. Detect Bass
    final bassClass = FftAnalyzer.detectBassPitchClass(
      magnitudes: magnitudes,
      sampleRate: sampleRate,
      fftSize: fftSize,
    );

    // 3. Match Chord
    final rawChord = ChordMatcher.matchChord(
      chromagram: chroma,
      bassPitchClass: bassClass,
      minEnergyThreshold: 0.12,
    );

    DetectedChord? stableChord = state.currentChord;

    if (rawChord != null) {
      _recentDetections.add(rawChord.chord);
      if (_recentDetections.length > 3) {
        _recentDetections.removeAt(0);
      }

      // Check if majority of last frames agree
      final chordFreq = <String, int>{};
      for (final c in _recentDetections) {
        chordFreq[c] = (chordFreq[c] ?? 0) + 1;
      }
      String? consensus;
      chordFreq.forEach((c, count) {
        if (count >= 2) consensus = c;
      });

      if (consensus != null) {
        stableChord = rawChord;

        // If recording and chord changed or is new
        if (state.isRecording) {
          final now = DateTime.now();
          if (_lastStableChord != consensus ||
              (_lastChordTime != null && now.difference(_lastChordTime!).inMilliseconds > 2500)) {
            _lastStableChord = consensus;
            _lastChordTime = now;

            final newItem = RecordedChordItem(
              chord: consensus!,
              durationMs: 2000,
              timestamp: now,
            );

            final updatedList = List<RecordedChordItem>.from(state.recordedChords)..add(newItem);
            final newKey = ChordMatcher.estimateKey(updatedList.map((c) => c.chord).toList());

            state = state.copyWith(
              recordedChords: updatedList,
              estimatedKey: newKey,
            );
          }
        }
      }
    } else {
      // Silence / pause: clear short-term detection window
      if (_recentDetections.isNotEmpty) {
        _recentDetections.removeAt(0);
      }
    }

    state = state.copyWith(
      chromagram: chroma,
      audioLevel: audioLevel,
      currentChord: stableChord,
    );
  }

  /// Formats the recorded chord list into a standard ChordPro song string.
  String generateSongContent({
    required String title,
    required String artist,
    String? key,
  }) {
    final finalKey = key ?? (state.estimatedKey?.replaceAll(RegExp(r'.*\('), '').replaceAll(')', '') ?? 'C');
    final chords = state.recordedChords.map((c) => c.chord).toList();

    final buffer = StringBuffer();
    buffer.writeln('{title: $title}');
    buffer.writeln('{artist: $artist}');
    buffer.writeln('{key: $finalKey}');
    buffer.writeln();
    buffer.writeln('[Introdução]');

    // Format chords in blocks of 4 per line
    for (int i = 0; i < chords.length; i += 4) {
      final chunk = chords.skip(i).take(4);
      buffer.writeln(chunk.map((c) => '[$c]').join('   '));
    }

    return buffer.toString();
  }
}
