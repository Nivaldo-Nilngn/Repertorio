// ignore_for_file: avoid_web_libraries_in_flutter
@JS()
library chord_ai_web;

import 'dart:async';
import 'dart:js_interop';

@JS('window.ChordAiAudioJS.start')
external JSPromise<JSBoolean> _jsStart();

@JS('window.ChordAiAudioJS.stop')
external void _jsStop();

@JS('window.ChordAiAudioJS.getSampleRate')
external JSNumber _jsGetSampleRate();

@JS('window.ChordAiAudioJS.getFrequencyData')
external JSUint8Array? _jsGetFrequencyData();

typedef AudioSpectrumCallback = void Function({
  required List<double> magnitudes,
  required double sampleRate,
  required int fftSize,
  required double audioLevel,
});

class AudioCaptureService {
  Timer? _timer;
  bool _isCapturing = false;

  bool get isCapturing => _isCapturing;

  Future<bool> start(AudioSpectrumCallback onSpectrum) async {
    if (_isCapturing) return true;

    try {
      final jsSuccess = await _jsStart().toDart;
      if (!jsSuccess.toDart) {
        return false;
      }

      _isCapturing = true;
      final sampleRate = _jsGetSampleRate().toDartDouble;

      // Sample every 80ms (~12 times per second)
      _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (!_isCapturing) return;

        final rawBuffer = _jsGetFrequencyData();
        if (rawBuffer == null) return;

        final dartList = rawBuffer.toDart;
        final count = dartList.length;

        final magnitudes = List<double>.generate(
          count,
          (i) => dartList[i] / 255.0,
        );

        // Calculate average RMS/level for VU meter
        double sum = 0.0;
        final checkLen = count > 200 ? 200 : count;
        for (int i = 0; i < checkLen; i++) {
          sum += magnitudes[i] * magnitudes[i];
        }
        final level = (sum > 0 ? (sum / checkLen) * 3.5 : 0.0).clamp(0.0, 1.0);

        onSpectrum(
          magnitudes: magnitudes,
          sampleRate: sampleRate,
          fftSize: 2048,
          audioLevel: level,
        );
      });

      return true;
    } catch (e) {
      print('[ChordAI] Error starting audio capture: $e');
      stop();
      return false;
    }
  }

  void stop() {
    _isCapturing = false;
    _timer?.cancel();
    _timer = null;
    try {
      _jsStop();
    } catch (_) {}
  }
}
