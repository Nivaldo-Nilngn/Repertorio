// Mobile stub — MIDI is not supported on Android/iOS (no Web MIDI API).
// All methods return safe no-op values so the rest of the app compiles
// and runs normally; the UI simply shows "MIDI não suportado" to the user.

import 'dart:async';
import 'midi_device_models.dart';

export 'midi_device_models.dart';

class MidiMessageEvent {
  final int command;
  final int note;
  final int velocity;
  final String portId;

  MidiMessageEvent({
    required this.command,
    required this.note,
    required this.velocity,
    required this.portId,
  });

  bool get isNoteOff => false;
  bool get isNoteOn => false;
  bool get isControlChange => false;

  @override
  String toString() =>
      'MidiMessageEvent(cmd: $command, note: $note, vel: $velocity, port: $portId)';
}

class MidiService {
  final _messageController = StreamController<MidiMessageEvent>.broadcast();
  final _stateChangeController = StreamController<void>.broadcast();

  Stream<MidiMessageEvent> get onMessage => _messageController.stream;
  Stream<void> get onStateChange => _stateChangeController.stream;

  bool get isInitialized => false;

  /// Always returns false on mobile — Web MIDI API is unavailable.
  Future<bool> initialize() async => false;

  List<MidiInputDevice> getInputs() => [];
  List<MidiOutputDevice> getOutputs() => [];

  bool sendMidiMessage(String portId, int command, int data1, int data2) =>
      false;

  void sendPanic(String portId, {int channel = 0}) {}

  void dispose() {
    _messageController.close();
    _stateChangeController.close();
  }
}
