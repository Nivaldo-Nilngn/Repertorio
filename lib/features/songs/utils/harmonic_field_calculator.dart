class HarmonicField {
  final String key;
  final String i;
  final String ii;
  final String iii;
  final String iv;
  final String v;
  final String vi;
  final String vii;

  const HarmonicField(this.key, this.i, this.ii, this.iii, this.iv, this.v, this.vi, this.vii);

  List<String> get diatonicChords => [i, ii, iii, iv, v, vi, vii];
}

class HarmonicFieldCalculator {
  static const Map<String, HarmonicField> _fields = {
    'C': HarmonicField('C', 'C', 'Dm', 'Em', 'F', 'G', 'Am', 'B°'),
    'G': HarmonicField('G', 'G', 'Am', 'Bm', 'C', 'D', 'Em', 'F#°'),
    'D': HarmonicField('D', 'D', 'Em', 'F#m', 'G', 'A', 'Bm', 'C#°'),
    'A': HarmonicField('A', 'A', 'Bm', 'C#m', 'D', 'E', 'F#m', 'G#°'),
    'E': HarmonicField('E', 'E', 'F#m', 'G#m', 'A', 'B', 'C#m', 'D#°'),
    'B': HarmonicField('B', 'B', 'C#m', 'D#m', 'E', 'F#', 'G#m', 'A#°'),
    'F#': HarmonicField('F#', 'F#', 'G#m', 'A#m', 'B', 'C#', 'D#m', 'E#°'),
    'Gb': HarmonicField('Gb', 'Gb', 'Abm', 'Bbm', 'Cb', 'Db', 'Ebm', 'F°'),
    'Db': HarmonicField('Db', 'Db', 'Ebm', 'Fm', 'Gb', 'Ab', 'Bbm', 'C°'),
    'C#': HarmonicField('C#', 'C#', 'D#m', 'E#m', 'F#', 'G#', 'A#m', 'B#°'),
    'Ab': HarmonicField('Ab', 'Ab', 'Bbm', 'Cm', 'Db', 'Eb', 'Fm', 'G°'),
    'Eb': HarmonicField('Eb', 'Eb', 'Fm', 'Gm', 'Ab', 'Bb', 'Cm', 'D°'),
    'Bb': HarmonicField('Bb', 'Bb', 'Cm', 'Dm', 'Eb', 'F', 'Gm', 'A°'),
    'F': HarmonicField('F', 'F', 'Gm', 'Am', 'Bb', 'C', 'Dm', 'E°'),
  };

  static HarmonicField? getField(String key) {
    if (key.isEmpty) return null;
    
    // Se for tom menor, acha a relativa maior
    if (key.endsWith('m') && !key.endsWith('dim')) {
       for (final field in _fields.values) {
         if (field.vi == key) return field;
       }
    }
    
    if (_fields.containsKey(key)) {
      return _fields[key];
    }

    return _fields[key.replaceAll('m', '')];
  }

  // Extrai a raiz limpa do acorde para comparação (ex: Cmaj7/E -> C, Dm7 -> Dm)
  static String extractRootChord(String rawChord) {
    // Remove notas de baixo (ex: /E)
    final chordNoBass = rawChord.split('/').first;
    
    final match = RegExp(r'^([CDEFGAB][#b]?)(m|dim|°|aug|\+)?').firstMatch(chordNoBass);
    if (match == null) return chordNoBass;
    
    final root = match.group(1)!;
    final mod = match.group(2) ?? '';
    
    if (mod == 'dim' || mod == '°') return '$root°';
    if (mod == 'm') return '${root}m';
    if (mod == 'aug' || mod == '+') return '${root}aug';
    return root;
  }
}
