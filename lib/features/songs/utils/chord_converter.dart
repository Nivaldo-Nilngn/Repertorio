class ChordConverter {
  static final _sectionRegex = RegExp(
    r'^\[(Intro|Introdução|Introducao|.*Parte.*|Verso.*|Verse.*|Pré-Refrão|Pre-Refrão|Pré-Refrao|Pre-Refrao|Pre-Chorus|Refrão|Refrao|Chorus|Ponte|Bridge|Solo|Final|Fim|Outro|Instrumental|Interlúdio|Interludio|Passagem|Riff|Medley.*).*?\]$',
    caseSensitive: false,
  );

  /// Converts standard text (chords above lyrics) to ChordPro format.
  static String textToChordPro(String text) {
    if (text.isEmpty) return '';

    final lines = text.replaceAll('\r', '').split('\n');
    final result = <String>[];
    
    final chordLineRegex = RegExp(r'^[\sA-G#b0-9majdimaugMmsusadd\/\(\)\-\+\|xX]*$');
    final containsChordRegex = RegExp(r'[A-G]');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Check if it is a section header like [Primeira Parte]
      if (_sectionRegex.hasMatch(trimmed)) {
        result.add(trimmed);
        continue;
      }

      // Check if current line is a potential chord line
      if (trimmed.isNotEmpty && chordLineRegex.hasMatch(line) && containsChordRegex.hasMatch(line)) {
        // Is the next line lyrics? (Must not be a chord line, and must not be a section header)
        if (i + 1 < lines.length && 
            lines[i + 1].trim().isNotEmpty && 
            !_sectionRegex.hasMatch(lines[i + 1].trim()) &&
            !chordLineRegex.hasMatch(lines[i + 1])) {
          final chordLine = line;
          final lyricLine = lines[i + 1];
          final mergedLine = _mergeChordsIntoLyrics(chordLine, lyricLine);
          result.add(mergedLine);
          i++; // skip next line since it was merged
        } else {
          // Just a standalone chord line (e.g. Intro chords or instrumental)
          final words = line.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
          final converted = words.map((w) {
            if (w == '|') return '|';
            if (RegExp(r'^\d+x$', caseSensitive: false).hasMatch(w)) return w;
            return '[$w]';
          }).join('  ');
          result.add(converted);
        }
      } else {
        result.add(line);
      }
    }

    return result.join('\n');
  }

  static String _mergeChordsIntoLyrics(String chordLine, String lyricLine) {
    final chordMatches = RegExp(r'\S+').allMatches(chordLine);
    String result = lyricLine;
    int offset = 0;
    
    for (final match in chordMatches) {
      final chord = match.group(0)!;
      int insertIndex = match.start;
      
      if (insertIndex > result.length - offset) {
         result = result.padRight(insertIndex + offset, ' ');
      }
      
      final actualIndex = insertIndex + offset;
      result = result.substring(0, actualIndex) + '[$chord]' + result.substring(actualIndex);
      offset += chord.length + 2;
    }
    
    return result;
  }

  /// Converts ChordPro format to standard text (chords above lyrics).
  static String chordProToText(String chordPro) {
    if (chordPro.isEmpty) return '';

    final lines = chordPro.split('\n');
    final result = <String>[];
    
    final chordRegex = RegExp(r'\[(.*?)\]');
    final tagRegex = RegExp(r'^\{.*?\}$');

    for (final line in lines) {
      final trimmed = line.trim();

      if (tagRegex.hasMatch(trimmed)) {
        final cMatch = RegExp(r'\{c:\s*(.*?)\}').firstMatch(trimmed);
        if (cMatch != null) {
          result.add('\n[${cMatch.group(1)!}]');
        }
        continue;
      }

      // Check if it is a section header like [Primeira Parte]
      if (_sectionRegex.hasMatch(trimmed)) {
        result.add(trimmed);
        continue;
      }
      
      if (!chordRegex.hasMatch(line)) {
        result.add(line);
        continue;
      }

      // Check if this line is purely chords without lyrics (e.g. [E5]  [B11/D#])
      final cleanText = line.replaceAll(chordRegex, '').trim();
      if (cleanText.isEmpty) {
        // Standalone chord line: just strip brackets and preserve spaces
        final chordsText = line.replaceAllMapped(chordRegex, (m) => m.group(1)!);
        result.add(chordsText);
        continue;
      }

      // Contains chords and lyrics: split into chord line and lyric line
      String chordLine = '';
      String lyricLine = '';
      
      int currentIndex = 0;
      for (final match in chordRegex.allMatches(line)) {
        final textBefore = line.substring(currentIndex, match.start);
        lyricLine += textBefore;
        
        chordLine = chordLine.padRight(lyricLine.length, ' ');
        chordLine += match.group(1)!;
        
        currentIndex = match.end;
      }
      lyricLine += line.substring(currentIndex);
      
      if (chordLine.trim().isNotEmpty) {
        result.add(chordLine);
      }
      if (lyricLine.trim().isNotEmpty) {
        result.add(lyricLine);
      }
    }
    
    return result.join('\n').trim();
  }
}
