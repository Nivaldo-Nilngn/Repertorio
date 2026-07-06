class ChordConverter {
  /// Converts standard text (chords above lyrics) to ChordPro format.
  static String textToChordPro(String text) {
    if (text.isEmpty) return '';

    final lines = text.split('\n');
    final result = <String>[];
    
    // Simple heuristic: a line is a chord line if it contains mostly chords and spaces.
    // A more robust check might look for valid chord names.
    final chordLineRegex = RegExp(r'^[\sA-G#b0-9majdimaugMmsusadd\/\(\)\-\+]*$');
    final containsChordRegex = RegExp(r'[A-G]');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Check if current line is a potential chord line
      if (line.trim().isNotEmpty && chordLineRegex.hasMatch(line) && containsChordRegex.hasMatch(line)) {
        // Is the next line lyrics?
        if (i + 1 < lines.length && lines[i + 1].trim().isNotEmpty && !chordLineRegex.hasMatch(lines[i + 1])) {
          // Merge chords into lyrics
          final chordLine = line;
          final lyricLine = lines[i + 1];
          final mergedLine = _mergeChordsIntoLyrics(chordLine, lyricLine);
          result.add(mergedLine);
          i++; // skip next line since it was merged
        } else {
          // Just a standalone chord line (or followed by empty line)
          // Convert to [Chord] format
          final words = line.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
          result.add(words.map((w) => '[$w]').join(' '));
        }
      } else {
        // Just lyrics or an empty line
        result.add(line);
      }
    }

    return result.join('\n');
  }

  static String _mergeChordsIntoLyrics(String chordLine, String lyricLine) {
    // Find all chords and their indices
    final chordMatches = RegExp(r'\S+').allMatches(chordLine);
    
    String result = lyricLine;
    int offset = 0;
    
    for (final match in chordMatches) {
      final chord = match.group(0)!;
      int insertIndex = match.start;
      
      // If the chord is placed further than the lyric line length, pad the lyric line
      if (insertIndex > result.length - offset) {
         result = result.padRight(insertIndex + offset, ' ');
      }
      
      final actualIndex = insertIndex + offset;
      
      // Insert chord in brackets
      result = result.substring(0, actualIndex) + '[$chord]' + result.substring(actualIndex);
      
      // Offset increases by the length of the inserted [chord] string
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
      if (tagRegex.hasMatch(line.trim())) {
        // Skip tags or just output them? We usually strip metadata out, but for section tags {c: Verse 1}, we can just print it.
        final cMatch = RegExp(r'\{c:\s*(.*?)\}').firstMatch(line.trim());
        if (cMatch != null) {
          result.add('\n' + cMatch.group(1)! + ':');
        }
        continue;
      }
      
      if (!chordRegex.hasMatch(line)) {
        result.add(line);
        continue;
      }

      // Contains chords. We need to split into chord line and lyric line.
      String chordLine = '';
      String lyricLine = '';
      
      int currentIndex = 0;
      for (final match in chordRegex.allMatches(line)) {
        final textBefore = line.substring(currentIndex, match.start);
        lyricLine += textBefore;
        
        // Pad chord line to match the visual length
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
