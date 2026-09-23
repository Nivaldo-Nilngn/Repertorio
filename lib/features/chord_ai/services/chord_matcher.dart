import 'dart:math' as math;
import '../models/detected_chord.dart';

class ChordTemplate {
  final String quality;
  final List<int> intervals; // Semitone offsets from root (e.g. [0, 4, 7] for Major)
  final double baseWeight;

  const ChordTemplate({
    required this.quality,
    required this.intervals,
    this.baseWeight = 1.0,
  });
}

class ChordMatcher {
  static const List<ChordTemplate> templates = [
    ChordTemplate(quality: '', intervals: [0, 4, 7], baseWeight: 1.0), // Major triad
    ChordTemplate(quality: 'm', intervals: [0, 3, 7], baseWeight: 1.0), // Minor triad
    ChordTemplate(quality: '7', intervals: [0, 4, 7, 10], baseWeight: 0.95), // Dominant 7th
    ChordTemplate(quality: '7M', intervals: [0, 4, 7, 11], baseWeight: 0.95), // Major 7th
    ChordTemplate(quality: 'm7', intervals: [0, 3, 7, 10], baseWeight: 0.95), // Minor 7th
    ChordTemplate(quality: 'sus4', intervals: [0, 5, 7], baseWeight: 0.9), // Sus4
    ChordTemplate(quality: 'sus2', intervals: [0, 2, 7], baseWeight: 0.9), // Sus2
    ChordTemplate(quality: 'add9', intervals: [0, 2, 4, 7], baseWeight: 0.9), // Add9
    ChordTemplate(quality: 'dim', intervals: [0, 3, 6], baseWeight: 0.85), // Diminished
  ];

  /// Matches a 12-element chromagram against known chord templates.
  /// Returns null if overall audio energy is too low (silence / background noise).
  static DetectedChord? matchChord({
    required List<double> chromagram,
    int? bassPitchClass,
    double minEnergyThreshold = 0.15,
  }) {
    if (chromagram.length != 12) return null;

    // Check if there is enough energy to detect a chord
    final maxVal = chromagram.reduce(math.max);
    final avgVal = chromagram.reduce((a, b) => a + b) / 12.0;

    if (maxVal < minEnergyThreshold || (maxVal - avgVal) < 0.1) {
      return null; // Silence or uniform noise
    }

    String bestRoot = '';
    String bestQuality = '';
    double bestScore = -1.0;
    List<String> bestActiveNotes = [];

    // Calculate active notes above 40% of max energy
    final activeNotes = <String>[];
    for (int i = 0; i < 12; i++) {
      if (chromagram[i] >= 0.4) {
        activeNotes.add(PitchClass.names[i]);
      }
    }

    // Test all 12 roots against all templates
    for (int rootIdx = 0; rootIdx < 12; rootIdx++) {
      for (final tmpl in templates) {
        double score = 0.0;
        double penalty = 0.0;

        // Positive correlation with expected chord tones
        for (final interval in tmpl.intervals) {
          final noteIdx = (rootIdx + interval) % 12;
          score += chromagram[noteIdx];
        }

        // Penalize notes that are loud but NOT in the chord
        for (int i = 0; i < 12; i++) {
          final interval = (i - rootIdx + 12) % 12;
          if (!tmpl.intervals.contains(interval)) {
            penalty += chromagram[i] * 0.35;
          }
        }

        final normalizedScore = (score / tmpl.intervals.length) * tmpl.baseWeight - penalty;

        if (normalizedScore > bestScore) {
          bestScore = normalizedScore;
          bestRoot = PitchClass.names[rootIdx];
          bestQuality = tmpl.quality;
          bestActiveNotes = activeNotes;
        }
      }
    }

    if (bestScore < 0.35) {
      return null;
    }

    // Determine bass / slash chord (e.g. D/F#, C/E)
    String? bassName;
    if (bassPitchClass != null) {
      final detectedBass = PitchClass.names[bassPitchClass];
      if (detectedBass != bestRoot) {
        bassName = detectedBass;
      }
    }

    final chordSymbol = bassName != null ? '$bestRoot$bestQuality/$bassName' : '$bestRoot$bestQuality';

    return DetectedChord(
      chord: chordSymbol,
      root: bestRoot,
      quality: bestQuality.isEmpty ? 'Maior' : bestQuality,
      bass: bassName,
      confidence: bestScore.clamp(0.0, 1.0),
      activeNotes: bestActiveNotes,
      timestamp: DateTime.now(),
    );
  }

  /// Harmonic field rule engine for key estimation based on chord sequence.
  static String estimateKey(List<String> chords) {
    if (chords.isEmpty) return 'Não identificado';

    final chordRoots = chords.map((c) {
      // Remove extensions (e.g. 'Em7' -> 'Em', 'G/B' -> 'G', 'C9' -> 'C')
      final clean = c.split('/')[0];
      return clean;
    }).toList();

    // Standard major scale diatonic triads: I, ii, iii, IV, V, vi, vii°
    final majorKeys = <String, List<String>>{
      'C': ['C', 'Dm', 'Em', 'F', 'G', 'Am', 'Bdim'],
      'G': ['G', 'Am', 'Bm', 'C', 'D', 'Em', 'F#dim'],
      'D': ['D', 'Em', 'F#m', 'G', 'A', 'Bm', 'C#dim'],
      'A': ['A', 'Bm', 'C#m', 'D', 'E', 'F#m', 'G#dim'],
      'E': ['E', 'F#m', 'G#m', 'A', 'B', 'C#m', 'D#dim'],
      'B': ['B', 'C#m', 'D#m', 'E', 'F#', 'G#m', 'A#dim'],
      'F#': ['F#', 'G#m', 'A#m', 'B', 'C#', 'D#m', 'Fdim'],
      'F': ['F', 'Gm', 'Am', 'Bb', 'C', 'Dm', 'Edim'],
      'Bb': ['Bb', 'Cm', 'Dm', 'Eb', 'F', 'Gm', 'Adim'],
      'Eb': ['Eb', 'Fm', 'Gm', 'Ab', 'Bb', 'Cm', 'Ddim'],
      'Ab': ['Ab', 'Bbm', 'Cm', 'Db', 'Eb', 'Fm', 'Gdim'],
      'Db': ['Db', 'Ebm', 'Fm', 'Gb', 'Ab', 'Bbm', 'Cdim'],
    };

    String bestKey = 'C';
    int maxMatches = -1;

    majorKeys.forEach((key, diatonicChords) {
      int matches = 0;
      for (final chord in chordRoots) {
        if (diatonicChords.any((d) => chord.startsWith(d))) {
          matches++;
        }
      }
      // Weight the first chord more heavily as it is often the tonic (I)
      if (chordRoots.isNotEmpty && diatonicChords.first == chordRoots.first) {
        matches += 2;
      }
      if (matches > maxMatches) {
        maxMatches = matches;
        bestKey = key;
      }
    });

    final ptKeyName = PitchClass.getPtName(bestKey);
    return '$ptKeyName Maior ($bestKey)';
  }
}
