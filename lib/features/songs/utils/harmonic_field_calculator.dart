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

  static bool areEnharmonicallyEquivalent(String chord1, String chord2) {
    if (chord1 == chord2) return true;
    
    // Simplificamos removendo modificadores temporariamente
    String root1 = extractRootChord(chord1);
    String root2 = extractRootChord(chord2);
    
    if (root1 == root2) return true;

    const equivalents = [
      {'C#', 'Db'}, {'D#', 'Eb'}, {'F#', 'Gb'}, {'G#', 'Ab'}, {'A#', 'Bb'}
    ];
    
    for (var eq in equivalents) {
      if (eq.contains(root1) && eq.contains(root2)) return true;
    }
    return false;
  }

  // Analisa os acordes extras para tentar detectar se houve uma modulação de tom
  static String? detectModulation(String currentKey, Set<String> extraChords) {
    if (extraChords.isEmpty) return null;
    
    final currentField = getField(currentKey);
    final currentMainKey = currentField?.key ?? currentKey;

    int bestScore = 0;
    String? bestKey;

    for (var entry in _fields.entries) {
      if (entry.key == currentMainKey) continue;
      
      final diatonicRoots = entry.value.diatonicChords.map((c) => extractRootChord(c)).toSet();
      int score = 0;
      
      for (var chord in extraChords) {
        String root = extractRootChord(chord);
        for (var diatonicRoot in diatonicRoots) {
          if (areEnharmonicallyEquivalent(root, diatonicRoot)) {
            score++;
            break;
          }
        }
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestKey = entry.key;
      }
    }
    
    // Exigimos que a maioria dos acordes (>= 60%) pertença ao novo tom para confirmar a modulação
    if (bestKey != null && bestScore >= (extraChords.length * 0.6).ceil()) {
      return bestKey;
    }
    
    return null;
  }
}
