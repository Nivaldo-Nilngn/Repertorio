@JS()
library midi_interop;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('window.kordMidiInterop.initWebMidi')
external JSPromise<JSBoolean> initWebMidi();

@JS('window.kordMidiInterop.getMidiInputs')
external JSArray<JSObject> getMidiInputs();

@JS('window.kordMidiInterop.getMidiOutputs')
external JSArray<JSObject> getMidiOutputs();

@JS('window.kordMidiInterop.sendMidiMessage')
external JSBoolean sendMidiMessage(JSString portId, JSUint8Array data);

@JS('window.kordMidiInterop.setDartCallbacks')
external void setDartCallbacks(JSFunction messageCallback, JSFunction stateChangeCallback);

class MidiInputDevice {
  final String id;
  final String name;
  final String manufacturer;
  final String state;
  final String connection;

  MidiInputDevice({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.state,
    required this.connection,
  });

  factory MidiInputDevice.fromJSObject(JSObject obj) {
    return MidiInputDevice(
      id: (obj.getProperty('id'.toJS) as JSString?)?.toDart ?? 'unknown',
      name: (obj.getProperty('name'.toJS) as JSString?)?.toDart ?? 'Unknown Device',
      manufacturer: (obj.getProperty('manufacturer'.toJS) as JSString?)?.toDart ?? '',
      state: (obj.getProperty('state'.toJS) as JSString?)?.toDart ?? '',
      connection: (obj.getProperty('connection'.toJS) as JSString?)?.toDart ?? '',
    );
  }
}

class MidiOutputDevice {
  final String id;
  final String name;
  final String manufacturer;
  final String state;
  final String connection;

  MidiOutputDevice({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.state,
    required this.connection,
  });

  factory MidiOutputDevice.fromJSObject(JSObject obj) {
    return MidiOutputDevice(
      id: (obj.getProperty('id'.toJS) as JSString?)?.toDart ?? 'unknown',
      name: (obj.getProperty('name'.toJS) as JSString?)?.toDart ?? 'Unknown Device',
      manufacturer: (obj.getProperty('manufacturer'.toJS) as JSString?)?.toDart ?? '',
      state: (obj.getProperty('state'.toJS) as JSString?)?.toDart ?? '',
      connection: (obj.getProperty('connection'.toJS) as JSString?)?.toDart ?? '',
    );
  }
}
