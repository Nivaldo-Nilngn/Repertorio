import 'dart:math' as math;

/// Analyzes frequency spectra and computes 12-element chromagrams for chord recognition.
class FftAnalyzer {
  static const double a4Freq = 440.0;
  static const double minFreq = 65.0; // C2 (~65.4 Hz)
  static const double maxFreq = 1200.0; // D6 (~1174.6 Hz)

  /// Converts a spectrum of FFT magnitudes into a 12-bin chromagram [C, C#, D, ... B].
  ///
  /// [magnitudes]: List of FFT bin magnitudes (linear amplitude >= 0).
  /// [sampleRate]: Sampling rate in Hz (typically 44100 or 48000).
  /// [fftSize]: Total FFT window size (typically 2048 or 4096).
  static List<double> computeChromagram({
    required List<double> magnitudes,
    required double sampleRate,
    required int fftSize,
  }) {
    final chroma = List<double>.filled(12, 0.0);
    final binBandwidth = sampleRate / fftSize;

    double maxEnergy = 0.0;

    for (int i = 1; i < magnitudes.length; i++) {
      final freq = i * binBandwidth;
      if (freq < minFreq || freq > maxFreq) continue;

      final mag = magnitudes[i];
      if (mag <= 0.0) continue;

      // MIDI note number: p = 69 + 12 * log2(freq / 440)
      final pitch = 69.0 + 12.0 * (math.log(freq / a4Freq) / math.ln2);
      final nearestNote = pitch.round();
      final pitchClass = (nearestNote % 12 + 12) % 12;

      // Weighting: closer to exact center of semitone gets higher weight
      final distFromSemitone = (pitch - nearestNote).abs();
      final weight = math.max(0.0, 1.0 - 2.0 * distFromSemitone);

      // Give slightly higher weight to lower fundamentals (C2-C4)
      final octaveBonus = freq < 400.0 ? 1.3 : 1.0;

      final energy = mag * weight * octaveBonus;
      chroma[pitchClass] += energy;

      if (chroma[pitchClass] > maxEnergy) {
        maxEnergy = chroma[pitchClass];
      }
    }

    // Normalize chromagram so values are in [0.0, 1.0]
    if (maxEnergy > 0.0001) {
      for (int i = 0; i < 12; i++) {
        chroma[i] = chroma[i] / maxEnergy;
      }
    }

    return chroma;
  }

  /// Detects the lowest prominent fundamental frequency to identify bass notes (slash chords).
  static int? detectBassPitchClass({
    required List<double> magnitudes,
    required double sampleRate,
    required int fftSize,
    double threshold = 0.25,
  }) {
    final binBandwidth = sampleRate / fftSize;
    // Look strictly in bass register (E1 ~41Hz up to E3 ~165Hz)
    int bestPitchClass = -1;
    double highestBassMag = 0.0;

    for (int i = 1; i < magnitudes.length; i++) {
      final freq = i * binBandwidth;
      if (freq < 40.0) continue;
      if (freq > 200.0) break;

      final mag = magnitudes[i];
      if (mag > highestBassMag) {
        highestBassMag = mag;
        final pitch = 69.0 + 12.0 * (math.log(freq / a4Freq) / math.ln2);
        bestPitchClass = (pitch.round() % 12 + 12) % 12;
      }
    }

    return bestPitchClass != -1 ? bestPitchClass : null;
  }
}
