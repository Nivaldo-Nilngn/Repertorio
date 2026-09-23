// Web implementation — only compiled on web targets.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'midi_device_models.dart';
import 'midi_web_service.dart' as js_interop;

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

  bool get isNoteOff => (command == 128) || (command == 144 && velocity == 0);
  bool get isNoteOn => command == 144 && velocity > 0;
  bool get isControlChange => command == 176;

  @override
  String toString() =>
      'MidiMessageEvent(cmd: $command, note: $note, vel: $velocity, port: $portId)';
}

class MidiService {
  final _messageController = StreamController<MidiMessageEvent>.broadcast();
  final _stateChangeController = StreamController<void>.broadcast();

  Stream<MidiMessageEvent> get onMessage => _messageController.stream;
  Stream<void> get onStateChange => _stateChangeController.stream;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<bool> initialize() async {
    if (_initialized) return true;

    js_interop.setDartCallbacks(
      _handleMidiMessage.toJS,
      _handleStateChange.toJS,
    );

    final result = await js_interop.initWebMidi().toDart;
    _initialized = result.isDefinedAndNotNull ? result.toDart : false;
    return _initialized;
  }

  void _handleMidiMessage(JSUint8Array dataArray, JSString portIdStr) {
    final data = dataArray.toDart;
    if (data.length >= 3) {
      final command = data[0];
      final note = data[1];
      final velocity = data[2];
      final portId = portIdStr.toDart;

      _messageController.add(MidiMessageEvent(
        command: command,
        note: note,
        velocity: velocity,
        portId: portId,
      ));
    }
  }

  void _handleStateChange(
      JSString portId, JSString name, JSString state, JSString connection) {
    _stateChangeController.add(null);
  }

  List<MidiInputDevice> getInputs() {
    if (!_initialized) return [];
    try {
      final jsInputs = js_interop.getMidiInputs().toDart;
      final inputs = <MidiInputDevice>[];
      for (var item in jsInputs) {
        if (item != null) {
          final obj = item as JSObject;
          inputs.add(MidiInputDevice(
            id: (obj.getProperty('id'.toJS) as JSString?)?.toDart ?? 'unknown',
            name: (obj.getProperty('name'.toJS) as JSString?)?.toDart ??
                'Unknown Device',
            manufacturer:
                (obj.getProperty('manufacturer'.toJS) as JSString?)?.toDart ??
                    '',
            state:
                (obj.getProperty('state'.toJS) as JSString?)?.toDart ?? '',
            connection:
                (obj.getProperty('connection'.toJS) as JSString?)?.toDart ??
                    '',
          ));
        }
      }
      return inputs;
    } catch (e) {
      print('Error getting MIDI inputs: $e');
      return [];
    }
  }

  List<MidiOutputDevice> getOutputs() {
    if (!_initialized) return [];
    try {
      final jsOutputs = js_interop.getMidiOutputs().toDart;
      final outputs = <MidiOutputDevice>[];
      for (var item in jsOutputs) {
        if (item != null) {
          final obj = item as JSObject;
          outputs.add(MidiOutputDevice(
            id: (obj.getProperty('id'.toJS) as JSString?)?.toDart ?? 'unknown',
            name: (obj.getProperty('name'.toJS) as JSString?)?.toDart ??
                'Unknown Device',
            manufacturer:
                (obj.getProperty('manufacturer'.toJS) as JSString?)?.toDart ??
                    '',
            state:
                (obj.getProperty('state'.toJS) as JSString?)?.toDart ?? '',
            connection:
                (obj.getProperty('connection'.toJS) as JSString?)?.toDart ??
                    '',
          ));
        }
      }
      return outputs;
    } catch (e) {
      print('Error getting MIDI outputs: $e');
      return [];
    }
  }

  bool sendMidiMessage(String portId, int command, int data1, int data2) {
    if (!_initialized) return false;
    final bytes = Uint8List.fromList([command, data1, data2]);
    final result = js_interop.sendMidiMessage(portId.toJS, bytes.toJS);
    return result.toDart;
  }

  void sendPanic(String portId, {int channel = 0}) {
    int ccCmd = 176 + (channel > 0 ? channel - 1 : 0);
    if (channel == 0) {
      for (int i = 0; i < 16; i++) {
        int cmd = 176 + i;
        sendMidiMessage(portId, cmd, 120, 0);
        sendMidiMessage(portId, cmd, 123, 0);
      }
    } else {
      sendMidiMessage(portId, ccCmd, 120, 0);
      sendMidiMessage(portId, ccCmd, 123, 0);
    }
  }

  void dispose() {
    _messageController.close();
    _stateChangeController.close();
  }
}
