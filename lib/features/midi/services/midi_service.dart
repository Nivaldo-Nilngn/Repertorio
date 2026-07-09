import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'midi_web_service.dart' as js_interop;

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
  String toString() => 'MidiMessageEvent(cmd: $command, note: $note, vel: $velocity, port: $portId)';
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

    // Set callbacks BEFORE init to ensure we catch early messages
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

  void _handleStateChange(JSString portId, JSString name, JSString state, JSString connection) {
    _stateChangeController.add(null);
  }

  List<js_interop.MidiInputDevice> getInputs() {
    if (!_initialized) return [];
    final inputs = js_interop.getMidiInputs().toDart;
    return inputs.map((obj) => js_interop.MidiInputDevice.fromJSObject(obj)).toList();
  }

  void dispose() {
    _messageController.close();
    _stateChangeController.close();
  }
}
