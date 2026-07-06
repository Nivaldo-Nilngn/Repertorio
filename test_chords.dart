import 'package:guitar_chord_library/guitar_chord_library.dart';

void main() {
  var instrument = GuitarChordLibrary.instrument(InstrumentType.guitar);
  print(instrument.getKeys());
  print(instrument.getChordsByKey('C')!.map((c) => c.suffix).toList());
}
