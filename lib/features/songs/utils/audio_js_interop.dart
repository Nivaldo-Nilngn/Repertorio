@JS()
library audio_interop;

import 'package:js/js.dart';

@JS('AdvancedAudioPlayerJS.init')
external void initAudioPlayer(String url, void Function() onLoad);

@JS('AdvancedAudioPlayerJS.play')
external void playAudio();

@JS('AdvancedAudioPlayerJS.pause')
external void pauseAudio();

@JS('AdvancedAudioPlayerJS.setPitch')
external void setPitch(double semitones);

@JS('AdvancedAudioPlayerJS.setSpeed')
external void setSpeed(double rate);

@JS('AdvancedAudioPlayerJS.seek')
external void seekAudio(double timeInSeconds);

@JS('AdvancedAudioPlayerJS.setLoop')
external void setLoop(double? start, double? end);

@JS('AdvancedAudioPlayerJS.getProgress')
external double getAudioProgress();
