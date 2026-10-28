enum ChordComplexity {
  basic, // Tríades Básicas (Maior e Menor)
  intermediate, // Intermediário (Tríades, Sétimas, Suspensos)
  advanced, // Avançado (Chord ai Full: Inversões / Slash Chords, Nonas, 62 Qualidades)
}

/// Sistema de redução e simplificação harmônica idêntico ao Chord ai v2.8.15
/// Permite ao músico alternar entre cifras simplificadas (iniciantes) e completas (profissionais)
class ChordSimplifier {
  /// Reduz o acorde de acordo com a complexidade selecionada
  static String simplify(String chord, ChordComplexity complexity) {
    if (chord.isEmpty || chord == '...' || chord == 'N/A') return chord;
    if (complexity == ChordComplexity.advanced) return chord;

    // Trata acordes com baixo invertido (slash chords, ex: C/E, G/B, Am/G)
    String baseChord = chord;
    String? bassNote;
    if (chord.contains('/')) {
      final parts = chord.split('/');
      baseChord = parts[0];
      bassNote = parts.length > 1 ? parts[1] : null;
    }

    // Extrai nota fundamental (Root) e qualidade harmônica
    String root = '';
    String quality = '';
    if (baseChord.length >= 2 && (baseChord[1] == '#' || baseChord[1] == 'b')) {
      root = baseChord.substring(0, 2);
      quality = baseChord.substring(2);
    } else {
      root = baseChord.substring(0, 1);
      quality = baseChord.substring(1);
    }

    // Nível 1: BÁSICO (Apenas tríades Maiores e Menores, sem baixo invertido)
    if (complexity == ChordComplexity.basic) {
      final lower = quality.toLowerCase();
      if (lower.startsWith('m') && !lower.startsWith('maj')) {
        return '${root}m';
      }
      if (lower.contains('dim')) {
        return '${root}m';
      }
      return root;
    }

    // Nível 2: INTERMEDIÁRIO (Tríades, Sétimas, Suspensos; mantém baixo se relevante)
    if (complexity == ChordComplexity.intermediate) {
      String reducedQuality = quality;

      if (quality == 'add9' || quality == '6' || quality == '69' || quality == '5' || quality == '-5') {
        reducedQuality = '';
      } else if (quality == 'madd9' || quality == 'minadd9' || quality == 'm6' || quality == 'min6' || quality == 'min69' || quality == 'm69') {
        reducedQuality = 'm';
      } else if (quality == '9' || quality == '11' || quality == '13' || quality == '7b5' || quality == '7b9' || quality == '7#9' || quality == '7#5') {
        reducedQuality = '7';
      } else if (quality == 'm9' || quality == 'm11' || quality == 'm13' || quality == 'min9' || quality == 'min11' || quality == 'min13' || quality == 'min7add11' || quality == 'min7add13' || quality == 'min7b9') {
        reducedQuality = 'm7';
      } else if (quality == 'M9' || quality == 'M11' || quality == 'M13' || quality == 'maj9' || quality == 'M7b5' || quality == 'M7#5') {
        reducedQuality = 'M7';
      } else if (quality == 'm7b5' || quality == 'min7b5' || quality == 'dim7' || quality == 'min9b5') {
        reducedQuality = 'dim';
      } else if (quality == 'minM7' || quality == 'minM9' || quality == 'minM11' || quality == 'minM13') {
        reducedQuality = 'm';
      } else if (quality == '9sus4') {
        reducedQuality = 'sus4';
      }

      if (bassNote != null && bassNote.isNotEmpty) {
        return '$root$reducedQuality/$bassNote';
      }
      return '$root$reducedQuality';
    }

    return chord;
  }
}
