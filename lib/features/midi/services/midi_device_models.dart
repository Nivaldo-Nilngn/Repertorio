/// Cross-platform data models for MIDI devices.
/// This file has NO platform-specific imports so it compiles on web and mobile.
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
}
