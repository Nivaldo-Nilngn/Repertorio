class ChordTransposer {
  static const List<String> _notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static const List<String> _flatNotes = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  static final Map<String, String> _cache = {};

  static String transpose(String chord, int steps) {
    if (steps == 0) return chord;
    
    final cacheKey = '${chord}_$steps';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    
    // Extract the root note and the rest of the chord
    final match = RegExp(r'^([CDEFGAB][#b]?)(.*)').firstMatch(chord);
    if (match == null) return chord; // Not a standard chord format

    final root = match.group(1)!;
    final modifier = match.group(2)!;

    // Normalize root note to flat/sharp index
    int noteIndex = _notes.indexOf(root);
    bool useFlats = false;
    
    if (noteIndex == -1) {
      noteIndex = _flatNotes.indexOf(root);
      if (noteIndex != -1) {
        useFlats = true;
      } else {
        return chord; // Could not parse root note
      }
    }

    // Shift index
    int newIndex = (noteIndex + steps) % 12;
    if (newIndex < 0) newIndex += 12;

    // Reconstruct chord
    final newRoot = useFlats ? _flatNotes[newIndex] : _notes[newIndex];
    
    // For bass notes (e.g. G/B), transpose the bass note too
    String finalModifier = modifier;
    if (modifier.contains('/')) {
      final parts = modifier.split('/');
      final transposedBass = transpose(parts[1], steps);
      finalModifier = '${parts[0]}/$transposedBass';
    }

    final result = newRoot + finalModifier;
    _cache[cacheKey] = result;
    return result;
  }
}
