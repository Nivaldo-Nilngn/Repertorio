/// Models for the Chord AI audio recognition and recorder.

class PitchClass {
  static const List<String> names = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static const List<String> ptNames = [
    'Dó', 'Dó#', 'Ré', 'Ré#', 'Mi', 'Fá', 'Fá#', 'Sol', 'Sol#', 'Lá', 'Lá#', 'Si'
  ];

  static String getPtName(String note) {
    final idx = names.indexOf(note);
    if (idx != -1) return ptNames[idx];
    return note;
  }
}

class DetectedChord {
  final String chord;
  final String root;
  final String quality;
  final String? bass;
  final double confidence;
  final List<String> activeNotes;
  final DateTime timestamp;

  const DetectedChord({
    required this.chord,
    required this.root,
    required this.quality,
    this.bass,
    required this.confidence,
    required this.activeNotes,
    required this.timestamp,
  });

  @override
  String toString() => '$chord ($quality, conf: ${(confidence * 100).toStringAsFixed(0)}%)';
}

class RecordedChordItem {
  final String chord;
  final int durationMs;
  final DateTime timestamp;

  const RecordedChordItem({
    required this.chord,
    required this.durationMs,
    required this.timestamp,
  });
}

class ChordAiState {
  final bool isListening;
  final bool isRecording;
  final DetectedChord? currentChord;
  final List<double> chromagram; // 12 values [0.0 - 1.0] for C, C#, D...
  final double audioLevel; // 0.0 to 1.0 (VU meter)
  final String? estimatedKey;
  final List<RecordedChordItem> recordedChords;
  final String? statusMessage;
  final String instrument; // 'guitar' or 'piano'

  const ChordAiState({
    this.isListening = false,
    this.isRecording = false,
    this.currentChord,
    this.chromagram = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.audioLevel = 0.0,
    this.estimatedKey,
    this.recordedChords = const [],
    this.statusMessage,
    this.instrument = 'guitar',
  });

  ChordAiState copyWith({
    bool? isListening,
    bool? isRecording,
    DetectedChord? currentChord,
    bool clearCurrentChord = false,
    List<double>? chromagram,
    double? audioLevel,
    String? estimatedKey,
    List<RecordedChordItem>? recordedChords,
    String? statusMessage,
    String? instrument,
  }) {
    return ChordAiState(
      isListening: isListening ?? this.isListening,
      isRecording: isRecording ?? this.isRecording,
      currentChord: clearCurrentChord ? null : (currentChord ?? this.currentChord),
      chromagram: chromagram ?? this.chromagram,
      audioLevel: audioLevel ?? this.audioLevel,
      estimatedKey: estimatedKey ?? this.estimatedKey,
      recordedChords: recordedChords ?? this.recordedChords,
      statusMessage: statusMessage ?? this.statusMessage,
      instrument: instrument ?? this.instrument,
    );
  }
}
