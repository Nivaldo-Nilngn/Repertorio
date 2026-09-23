// Web-only JS interop bindings for the Web MIDI API.
// This file is only compiled on web targets (dart.library.html).
// ignore_for_file: avoid_web_libraries_in_flutter

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
external void setDartCallbacks(
    JSFunction messageCallback, JSFunction stateChangeCallback);
