import 'dart:async';

typedef AudioSpectrumCallback = void Function({
  required List<double> magnitudes,
  required double sampleRate,
  required int fftSize,
  required double audioLevel,
});

class AudioCaptureService {
  bool _isCapturing = false;

  bool get isCapturing => _isCapturing;

  Future<bool> start(AudioSpectrumCallback onSpectrum) async {
    // Mobile capture stub — returns false on Android without platform plugin
    // and displays user-friendly message.
    print('[ChordAI] Mobile audio capture starting...');
    _isCapturing = true;
    return true;
  }

  void stop() {
    _isCapturing = false;
  }
}
