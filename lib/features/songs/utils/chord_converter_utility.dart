class ChordConverterUtility {
  static final _chordRegex = RegExp(
    r'^([A-G][#b]?)(m|min|maj|M|sus|sus2|sus4)?(dim|aug|\+|-|º|°)?(2|4|5|6|7|9|11|13)?(\([^)]+\))?(\/[A-G][#b]?)?$',
  );

  /// Checks if a string token is a valid chord.
  static bool _isChord(String token) {
    if (token.isEmpty) return false;
    // Allow parentheses around chords like (C)
    final cleanToken = token.replaceAll(RegExp(r'[()]'), '');
    return _chordRegex.hasMatch(cleanToken);
  }

  /// Determines if a line consists predominantly of chords.
  static bool _isChordLine(String line) {
    if (line.trim().isEmpty) return false;

    // Detect Tablature lines and bypass
    if (line.contains('|-') || line.contains('-|') || RegExp(r'-{3,}').hasMatch(line) || RegExp(r'^[eBGDAmE]\|').hasMatch(line.trim())) {
      return false;
    }

    final tokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return false;

    int chordCount = 0;
    int nonChordCount = 0;

    for (final token in tokens) {
      if (_isChord(token)) {
        chordCount++;
      } else {
        final lower = token.toLowerCase();
        if (lower == 'bis' || lower.contains('x') || token == '|' || token == '-' || lower == 'intro:' || lower == 'intro') {
          // Ignore structural markers or repeat signs
        } else {
          nonChordCount++;
        }
      }
    }
    // If it has at least one chord and no regular words, it's a chord line
    return chordCount > 0 && chordCount >= nonChordCount;
  }

  /// Extracts chords and their starting indices from a chord line.
  static List<Map<String, dynamic>> _extractChords(String line) {
    final List<Map<String, dynamic>> chords = [];
    final regex = RegExp(r'\S+');
    for (final match in regex.allMatches(line)) {
      final token = match.group(0)!;
      if (_isChord(token)) {
        chords.add({
          'chord': token.replaceAll(RegExp(r'[()]'), ''),
          'index': match.start,
        });
      }
    }
    return chords;
  }

  /// Converts standard text (chords above lyrics) to ChordPro format.
  static String convertStandardToChordPro(String input) {
    final lines = input.split('\n');
    final List<String> outputLines = [];

    for (int i = 0; i < lines.length; i++) {
      final currentLine = lines[i];

      // If the line is empty or just spaces, keep it
      if (currentLine.trim().isEmpty) {
        outputLines.add(currentLine);
        continue;
      }

      if (_isChordLine(currentLine)) {
        // It's a chord line
        final chordsInfo = _extractChords(currentLine);

        // Check if the next line is lyrics
        bool isNextLineLyrics = false;
        String nextLine = '';
        if (i + 1 < lines.length) {
          nextLine = lines[i + 1];
          if (nextLine.trim().isNotEmpty && !_isChordLine(nextLine)) {
            isNextLineLyrics = true;
          }
        }

        if (isNextLineLyrics) {
          // Merge chords into the next line (lyrics)
          // We must process from right to left (reverse order) so that string insertion doesn't mess up indices
          String mergedLine = nextLine;
          final reversedChords = chordsInfo.reversed.toList();

          for (final chordInfo in reversedChords) {
            final String chord = chordInfo['chord'];
            int index = chordInfo['index'];

            // Pad the lyric line if it's shorter than the chord's position
            if (index > mergedLine.length) {
              mergedLine = mergedLine.padRight(index, ' ');
            }

            // Insert the chord in brackets
            mergedLine =
                mergedLine.substring(0, index) +
                '[$chord]' +
                mergedLine.substring(index);
          }

          outputLines.add(mergedLine);
          i++; // Skip the next line since we merged it
        } else {
          // The next line is NOT lyrics (it's either empty, another chord line, or end of file)
          // This means this is just a standalone chord line (like an Intro or Interlude)
          final parts = <String>[];
          final regex = RegExp(r'\S+');
          int lastEnd = 0;
          for (final match in regex.allMatches(currentLine)) {
            parts.add(currentLine.substring(lastEnd, match.start));
            final token = match.group(0)!;
            if (_isChord(token)) {
              parts.add('[${token.replaceAll(RegExp(r'[()]'), '')}]');
            } else {
              parts.add(token);
            }
            lastEnd = match.end;
          }
          parts.add(currentLine.substring(lastEnd));
          outputLines.add(parts.join(''));
        }
      } else {
        // Not a chord line (just normal text, maybe section headers or lyrics without chords)

        // Let's also automatically bracket section headers if they are common words like Intro, Verse
        final sectionRegex = RegExp(
          r'^(Intro|Introdução|Parte|Primeira Parte|Segunda Parte|Refrão|Coro|Ponte|Solo|Fim|Outro)([:\s]*)$',
          caseSensitive: false,
        );
        if (sectionRegex.hasMatch(currentLine.trim()) &&
            !currentLine.contains('[')) {
          outputLines.add('[${currentLine.trim().replaceAll(':', '')}]');
        } else {
          outputLines.add(currentLine);
        }
      }
    }

    return outputLines.join('\n');
  }
  /// Converts a ChordPro line like "[G]Estou [Em]preparando" into two strings:
  /// - chordsRow: "G         Em"
  /// - lyricsRow: "Estou preparando"
  static Map<String, String> _chordProLineToTraditional(String line) {
    final chordRegex = RegExp(r'\[([^\]]+)\]');
    final chordsBuffer = StringBuffer();
    final lyricsBuffer = StringBuffer();

    int currentPos = 0; // current position in lyric output

    final matches = chordRegex.allMatches(line).toList();

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      // Lyrics before this chord
      final lyricsBefore = line.substring(currentPos, match.start);
      lyricsBuffer.write(lyricsBefore);

      // Determine chord
      final chord = match.group(1)!;

      // The chord goes at the current position in the chord row
      // Pad chords row to align with current lyrics position
      final chordCol = lyricsBuffer.length;
      while (chordsBuffer.length < chordCol) {
        chordsBuffer.write(' ');
      }
      chordsBuffer.write(chord);

      // Add space after chord in chord row if next chord is close
      if (i + 1 < matches.length) {
        final nextMatch = matches[i + 1];
        final lyricsSegment = line.substring(match.end, nextMatch.start);
        lyricsBuffer.write(lyricsSegment);
        currentPos = nextMatch.start;

        // Ensure there's at least one space after chord in chord row
        final minNextCol = chordCol + chord.length + 1;
        final actualNextCol = lyricsBuffer.length;
        if (chordsBuffer.length < actualNextCol) {
          while (chordsBuffer.length < actualNextCol) { chordsBuffer.write(' '); }
        } else if (chordsBuffer.length < minNextCol) {
          while (chordsBuffer.length < minNextCol) { chordsBuffer.write(' '); }
        }
      } else {
        // last chord
        final rest = line.substring(match.end);
        lyricsBuffer.write(rest);
        currentPos = line.length;
      }
    }

    if (currentPos < line.length) {
      lyricsBuffer.write(line.substring(currentPos));
    }

    return {
      'chords': chordsBuffer.toString(),
      'lyrics': lyricsBuffer.toString(),
    };
  }

  /// Converts ChordPro format to traditional Brazilian cifra format
  /// (chords above the lyrics line).
  ///
  /// Example:
  ///   Input:  "[G]Estou preparando um [Em]caminho"
  ///   Output: "G                   Em\nEstou preparando um caminho"
  static String convertChordProToTraditional(String chordProText) {
    final lines = chordProText.split('\n');
    final output = <String>[];
    final chordInLineRegex = RegExp(r'\[([^\]]+)\]');

    for (final rawLine in lines) {
      final line = rawLine.trimRight();

      // Empty lines
      if (line.trim().isEmpty) {
        output.add('');
        continue;
      }

      // Section headers like [Primeira Parte], [Refrão] etc.
      // These are lines that consist ONLY of a single bracketed label
      final singleBracket = RegExp(r'^\[([^\]]+)\]\s*$');
      if (singleBracket.hasMatch(line.trim())) {
        output.add(line); // keep as-is: [Primeira Parte]
        continue;
      }

      // Lines with inline chord notation [G]texto
      if (chordInLineRegex.hasMatch(line)) {
        final result = _chordProLineToTraditional(line);
        final chords = result['chords']!;
        final lyrics = result['lyrics']!;

        // Only output chord row if there are actual chords
        if (chords.trim().isNotEmpty) {
          output.add(chords);
        }
        if (lyrics.trim().isNotEmpty || output.isNotEmpty) {
          output.add(lyrics);
        }
        continue;
      }

      // Plain lines (no chords) - metadata or tablature
      output.add(line);
    }

    return output.join('\n');
  }
}
