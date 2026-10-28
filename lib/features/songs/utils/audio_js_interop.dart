// ignore_for_file: avoid_web_libraries_in_flutter
@JS()
library audio_interop;

import 'dart:js_interop';
import 'dart:typed_data';
@JS('AdvancedAudioPlayerJS.init')
external void _jsInitAudioPlayer(JSString url, JSFunction onLoad);

void initAudioPlayer(String url, void Function() onLoad) {
  _jsInitAudioPlayer(url.toJS, onLoad.toJS);
}

@JS('AdvancedAudioPlayerJS.play')
external void playAudio();

@JS('AdvancedAudioPlayerJS.pause')
external void pauseAudio();

@JS('AdvancedAudioPlayerJS.setPitch')
external void _jsSetPitch(JSNumber semitones);

void setPitch(double semitones) => _jsSetPitch(semitones.toJS);

@JS('AdvancedAudioPlayerJS.setSpeed')
external void _jsSetSpeed(JSNumber rate);

void setSpeed(double rate) => _jsSetSpeed(rate.toJS);

@JS('AdvancedAudioPlayerJS.seek')
external void _jsSeekAudio(JSNumber timeInSeconds);

void seekAudio(double timeInSeconds) => _jsSeekAudio(timeInSeconds.toJS);

@JS('AdvancedAudioPlayerJS.setLoop')
external void _jsSetLoop(JSNumber? start, JSNumber? end);

void setLoop(double? start, double? end) => _jsSetLoop(start?.toJS, end?.toJS);

@JS('AdvancedAudioPlayerJS.getProgress')
external JSNumber _jsGetAudioProgress();

double getAudioProgress() => _jsGetAudioProgress().toDartDouble;

@JS('window.AdvancedAudioPlayerJS.getRawPCMData')
external JSFloat32Array? _jsGetRawPCMData();

@JS('window.AdvancedAudioPlayerJS.getSampleRateOfBuffer')
external JSNumber _jsGetSampleRateOfBuffer();

class AudioBufferExtractor {
  static Float32List? extractSamples() {
    final jsArray = _jsGetRawPCMData();
    if (jsArray == null) return null;
    return jsArray.toDart;
  }

  static double getSampleRate() => _jsGetSampleRateOfBuffer().toDartDouble;
}
