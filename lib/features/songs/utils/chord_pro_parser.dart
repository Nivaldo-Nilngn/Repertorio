class ParsedSong {
  final String title;
  final String artist;
  final String key;
  final String video;
  final String ritmo;
  final String capo;
  final String shape;
  final List<SongLine> lines;

  ParsedSong({
    required this.title,
    required this.artist,
    required this.key,
    required this.video,
    this.ritmo = '',
    this.capo = '',
    this.shape = '',
    required this.lines,
  });
}

class SongLine {
  final String lyrics;
  final List<ChordPosition> chords;
  final String? type; // Ex: 'comment'
  final bool isInline;

  SongLine({
    required this.lyrics,
    required this.chords,
    this.type,
    this.isInline = false,
  });
}

class ChordPosition {
  final int index;
  final String chord;

  ChordPosition({required this.index, required this.chord});
}

class ChordProParser {
  static ParsedSong parse(String chordProText) {
    String title = '';
    String artist = '';
    String key = '';
    String video = '';
    String ritmo = '';
    String capo = '';
    String shape = '';
    List<SongLine> lines = [];

    final regex = RegExp(r'\[(.*?)\]');

    for (var rawLine in chordProText.split('\n')) {
      var line = rawLine.trimRight();
      if (line.isEmpty) {
        lines.add(SongLine(lyrics: '', chords: []));
        continue;
      }

      // Dynamic fallback: If a line contains | and has no brackets [ ] but contains chords,
      // wrap the chord words in brackets automatically so that the rest of the parsing is 100% correct!
      if (!line.contains('[') && !line.startsWith('{') && line.contains('|')) {
        final words = line.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
        
        final chordRegex = RegExp(
          r'^[A-G][b#]?(?:m|M|maj|min|sus|dim|aug|add|no|\d+)*[\(\)\d\+\-]*(?:/[A-G][b#]?(?:m|M|maj|min|sus|dim|aug|add|no|\d+)*[\(\)\d\+\-]*)?$',
          caseSensitive: false,
        );
        
        bool hasValidChord = false;
        for (var w in words) {
          if (w != '|' && chordRegex.hasMatch(w)) {
            hasValidChord = true;
            break;
          }
        }
        
        if (hasValidChord) {
          line = words.map((w) {
            if (w == '|') return '|';
            if (RegExp(r'^\d+x$', caseSensitive: false).hasMatch(w)) return w;
            if (chordRegex.hasMatch(w)) {
              return '[$w]';
            }
            return w;
          }).join(' ');
        }
      }

      // Metadata directives (e.g., {title: Amazing Grace})
      if (line.startsWith('{') && line.endsWith('}')) {
        final content = line.substring(1, line.length - 1);
        final parts = content.split(':');
        if (parts.length >= 2) {
          final directive = parts[0].trim().toLowerCase();
          final value = parts.sublist(1).join(':').trim();

          if (directive == 'title' || directive == 't') {
            title = value;
          } else if (directive == 'artist') {
            artist = value;
          } else if (directive == 'key') {
            key = value;
          } else if (directive == 'video') {
            video = value;
          } else if (directive == 'ritmo' || directive == 'r') {
            ritmo = value;
          } else if (directive == 'capo') {
            capo = value;
          } else if (directive == 'shape') {
            shape = value;
          } else if (directive == 'c' || directive == 'comment') {
            final lowerVal = value.toLowerCase();
            if (lowerVal.startsWith('ritmo:')) {
              ritmo = value.substring(6).trim();
            } else if (lowerVal.startsWith('capo:')) {
              capo = value.substring(5).trim();
            } else if (lowerVal.startsWith('forma:')) {
              shape = value.substring(6).trim();
            } else if (lowerVal.startsWith('shape:')) {
              shape = value.substring(6).trim();
            }
            lines.add(SongLine(lyrics: value, chords: [], type: 'comment'));
          }
        }
        continue;
      }

      // Line with chords (e.g., [G]Amazing [D]Grace)
      List<ChordPosition> chords = [];
      String lyrics = '';
      int currentLyricsIndex = 0;
      
      int lastMatchEnd = 0;
      for (final match in regex.allMatches(line)) {
        String chordText = match.group(1)!;
        final lowerText = chordText.toLowerCase();
        
        final knownSections = {
          'intro', 'introdução', 'introducao', 'solo', 'refrão', 'refrao',
          'chorus', 'verse', 'verso', 'ponte', 'bridge', 'final', 'fim',
          'outro', 'instrumental', 'inst', 'interlúdio', 'interludio',
          'pre-chorus', 'pre-refrão', 'pre-refrao', 'pré-refrão', 'pré-refrao',
          'primeira parte', 'segunda parte', 'terceira parte', 'quarta parte'
        };
        if (chordText.contains(' ') || chordText.length > 8 || knownSections.contains(lowerText)) {
          lyrics += line.substring(lastMatchEnd, match.end);
          currentLyricsIndex += (match.end - lastMatchEnd);
        } else {
          lyrics += line.substring(lastMatchEnd, match.start);
          currentLyricsIndex += (match.start - lastMatchEnd);
          
          chords.add(ChordPosition(
            index: currentLyricsIndex,
            chord: chordText,
          ));
        }
        
        lastMatchEnd = match.end;
      }
      lyrics += line.substring(lastMatchEnd);

      final lyricsWithoutBrackets = lyrics.replaceAll(RegExp(r'\[.*?\]'), '').replaceAll('|', '').trim();
      final isInlineLine = chords.isNotEmpty && lyricsWithoutBrackets.isEmpty;
      lines.add(SongLine(lyrics: lyrics, chords: chords, isInline: isInlineLine));
    }

    return ParsedSong(
      title: title,
      artist: artist,
      key: key,
      video: video,
      ritmo: ritmo,
      capo: capo,
      shape: shape,
      lines: lines,
    );
  }
}

class SongSection {
  final String title;
  final List<RoadmapRow> rows;
  final bool isObs;
  final String? obsText;

  SongSection({
    required this.title,
    required this.rows,
    this.isObs = false,
    this.obsText,
  });
}

class RoadmapRow {
  final String? hint;
  final List<List<String>> measures; // list of chords per measure
  final String? repetition; // e.g. "2x"

  RoadmapRow({
    this.hint,
    required this.measures,
    this.repetition,
  });
}

class SongRoadmapBuilder {
  static List<SongSection> build(ParsedSong parsedSong) {
    List<SongSection> sections = [];
    
    // Default starting section if no comment is found yet
    String currentSectionTitle = 'INTRODUÇÃO';
    List<RoadmapRow> currentRows = [];
    
    List<List<String>> paragraphMeasures = [];
    String? paragraphHint;
    String? paragraphRepetition;

    List<RoadmapRow> _processParagraphMeasures(List<List<String>> measures, String? hint, String? baseRepetition) {
      if (measures.isEmpty) return [];
      
      List<RoadmapRow> result = [];
      List<List<String>> current = List.from(measures);
      
      while (current.isNotEmpty) {
        bool foundSplit = false;
        
        for (int start = 0; start <= current.length - 2; start++) {
          int maxL = (current.length - start) ~/ 2;
          for (int L = maxL; L >= 1; L--) {
            final chunk1 = current.sublist(start, start + L);
            final chunk2 = current.sublist(start + L, start + 2 * L);
            if (_areMeasuresEqual(chunk1, chunk2)) {
              if (start > 0) {
                result.add(RoadmapRow(
                  hint: result.isEmpty ? hint : null,
                  measures: current.sublist(0, start),
                ));
              }
              
              int count = 2;
              int nextIdx = start + 2 * L;
              while (nextIdx + L <= current.length) {
                final nextChunk = current.sublist(nextIdx, nextIdx + L);
                if (_areMeasuresEqual(chunk1, nextChunk)) {
                  count++;
                  nextIdx += L;
                } else {
                  break;
                }
              }
              
              result.add(RoadmapRow(
                hint: (start == 0 && result.isEmpty) ? hint : null,
                measures: chunk1,
                repetition: '${count}x',
              ));
              
              current = current.sublist(nextIdx);
              foundSplit = true;
              break;
            }
          }
          if (foundSplit) break;
        }
        
        if (!foundSplit) {
          result.add(RoadmapRow(
            hint: result.isEmpty ? hint : null,
            measures: current,
            repetition: (result.length == 0) ? baseRepetition : null,
          ));
          break;
        }
      }
      
      if (result.length == 1 && baseRepetition != null && result[0].repetition == null) {
        result[0] = RoadmapRow(
          hint: result[0].hint,
          measures: result[0].measures,
          repetition: baseRepetition,
        );
      }
      
      return result;
    }

    void saveCurrentParagraph() {
      if (paragraphMeasures.isNotEmpty) {
        final measuresCopy = List<List<String>>.from(paragraphMeasures);
        
        // Use our new dynamic splitting and repetition detector
        final processedRows = _processParagraphMeasures(measuresCopy, paragraphHint, paragraphRepetition);
        currentRows.addAll(processedRows);
        
        paragraphMeasures.clear();
        paragraphHint = null;
        paragraphRepetition = null;
      }
    }

    void saveCurrentSection() {
      saveCurrentParagraph();
      if (currentRows.isNotEmpty) {
        sections.add(SongSection(
          title: currentSectionTitle,
          rows: List.from(currentRows),
        ));
        currentRows.clear();
      }
    }

    final sectionKeywords = {
      'intro', 'introdução', 'introducao', 'solo', 'refrão', 'refrao', 
      'chorus', 'verse', 'verso', 'primeira parte', 'segunda parte', 
      'ponte', 'bridge', 'final', 'fim', 'outro', 'instrumental', 'interlúdio', 'interludio',
      'pre-refrão', 'pre-refrao', 'pré-refrão', 'pré-refrao', 'pre-chorus'
    };

    for (var line in parsedSong.lines) {
      final cleanLyrics = line.lyrics.trim();
      final hasChords = line.chords.isNotEmpty;

      // Ignore tab lines (lines containing tuning headers or strings of hyphens or tab titles)
      final isTab = cleanLyrics.contains('--') || 
                    RegExp(r'^[eBgDaE]\|').hasMatch(cleanLyrics) ||
                    cleanLyrics.toLowerCase().contains('tablatura') ||
                    cleanLyrics.toLowerCase().contains('tab -') ||
                    cleanLyrics.toLowerCase().startsWith('tab:');
      if (isTab) {
        continue;
      }

      // Check if it's an empty line (paragraph separator)
      if (cleanLyrics.isEmpty && !hasChords) {
        saveCurrentParagraph();
        continue;
      }

      // Normalize line content to check for section/obs headers
      final commentText = cleanLyrics;
      final cleanComment = commentText.replaceAll('[', '').replaceAll(']', '').trim();
      final lowerComment = cleanComment.toLowerCase();

      // Check if it's an observation (comment or plain line starting with OBS)
      if (lowerComment.startsWith('obs:') || lowerComment.startsWith('obs ')) {
        saveCurrentSection();
        sections.add(SongSection(
          title: 'OBS',
          rows: [],
          isObs: true,
          obsText: cleanComment.substring(lowerComment.startsWith('obs:') ? 4 : 3).trim(),
        ));
        continue;
      }

      // Check if this line itself is a section title (comment or bracketed text, or plain matching word)
      bool isSectionLine = false;
      String matchedTitle = '';

      if (line.type == 'comment') {
        for (var kw in sectionKeywords) {
          if (lowerComment == kw || lowerComment.startsWith('$kw ') || lowerComment.startsWith('$kw:')) {
            isSectionLine = true;
            matchedTitle = cleanComment;
            break;
          }
        }
      } else if (!hasChords && cleanLyrics.isNotEmpty) {
        // If it's a plain line (no chords), check if it matches a bracketed keyword like [Primeira Parte]
        final bracketMatch = RegExp(r'^\[(.*?)\]$').firstMatch(cleanLyrics);
        if (bracketMatch != null) {
          final bracketContent = bracketMatch.group(1)!.trim();
          final lowerBracket = bracketContent.toLowerCase();
          for (var kw in sectionKeywords) {
            if (lowerBracket == kw || lowerBracket.startsWith('$kw ') || lowerBracket.startsWith('$kw:')) {
              isSectionLine = true;
              matchedTitle = bracketContent;
              break;
            }
          }
        } else {
          // Check if plain text matches a section keyword exactly
          for (var kw in sectionKeywords) {
            if (lowerComment == kw || lowerComment == '$kw:') {
              isSectionLine = true;
              matchedTitle = cleanComment;
              break;
            }
          }
        }
      }

      if (isSectionLine) {
        saveCurrentSection();
        currentSectionTitle = matchedTitle.toUpperCase();
        continue;
      }

      // If it's a comment but not a section/obs, treat it as a hint for current paragraph
      if (line.type == 'comment') {
        if (paragraphHint == null && cleanLyrics.isNotEmpty) {
          paragraphHint = cleanLyrics;
        }
        continue;
      }

      if (hasChords) {
        // Parse chords and measures
        List<List<String>> lineMeasures = [];

        // Extract repetition count from end of line if present (e.g. 2x, 3x)
        final repRegex = RegExp(r'\b(\d+x|\d+\s*vezes)\b', caseSensitive: false);
        final rawLineText = line.lyrics;
        final repMatch = repRegex.firstMatch(rawLineText);
        if (repMatch != null) {
          paragraphRepetition = repMatch.group(1);
        }

        // Split chords into measures
        if (rawLineText.contains('|')) {
          List<int> barIndices = [];
          for (int i = 0; i < rawLineText.length; i++) {
            if (rawLineText[i] == '|') {
              barIndices.add(i);
            }
          }
          
          List<List<String>> segments = List.generate(barIndices.length + 1, (_) => []);
          for (var chordPos in line.chords) {
            int segmentIndex = 0;
            while (segmentIndex < barIndices.length && chordPos.index > barIndices[segmentIndex]) {
              segmentIndex++;
            }
            segments[segmentIndex].add(chordPos.chord);
          }
          
          for (var segment in segments) {
            if (segment.isNotEmpty) {
              lineMeasures.add(segment);
            }
          }
        } else {
          // No bar lines: treat each chord in line.chords as a separate measure
          for (var chordPos in line.chords) {
            lineMeasures.add([chordPos.chord]);
          }
        }

        if (lineMeasures.isNotEmpty) {
          paragraphMeasures.addAll(lineMeasures);
        }

        // Determine hint for this row if not set
        if (paragraphHint == null) {
          final cleanLyricHint = rawLineText.replaceAll(RegExp(r'\[.*?\]'), '').trim();
          if (cleanLyricHint.isNotEmpty) {
            paragraphHint = cleanLyricHint.replaceAll(repRegex, '').trim();
          }
        }
      } else {
        // Lyric line without chords: save as pending hint for current paragraph if not set
        if (paragraphHint == null && cleanLyrics.isNotEmpty) {
          paragraphHint = cleanLyrics;
        }
      }
    }

    // Save final section
    saveCurrentSection();

    // 1. Collapse consecutive duplicate rows within each section
    for (var section in sections) {
      if (section.isObs || section.rows.isEmpty) continue;
      
      List<RoadmapRow> collapsedRows = [];
      RoadmapRow? activeRow;
      
      for (var row in section.rows) {
        if (activeRow == null) {
          activeRow = row;
        } else {
          if (_areMeasuresEqual(activeRow.measures, row.measures)) {
            int count1 = _parseRepetition(activeRow.repetition);
            int count2 = _parseRepetition(row.repetition);
            int total = count1 + count2;
            
            activeRow = RoadmapRow(
              hint: activeRow.hint,
              measures: activeRow.measures,
              repetition: '${total}x',
            );
          } else {
            collapsedRows.add(activeRow);
            activeRow = row;
          }
        }
      }
      if (activeRow != null) {
        collapsedRows.add(activeRow);
      }
      
      section.rows.clear();
      section.rows.addAll(collapsedRows);
    }

    // 2. Collapse duplicate sections into OBS Volta sections
    List<SongSection> finalSections = [];
    for (int i = 0; i < sections.length; i++) {
      final current = sections[i];
      if (current.isObs) {
        finalSections.add(current);
        continue;
      }

      int duplicateIndex = -1;
      int multiplier = 0;
      for (int j = 0; j < finalSections.length; j++) {
        final prev = finalSections[j];
        if (!prev.isObs) {
          int mult = _getSectionMultiplier(prev, current);
          if (mult > 0) {
            duplicateIndex = j;
            multiplier = mult;
            break;
          }
        }
      }

      if (duplicateIndex != -1) {
        finalSections.add(SongSection(
          title: 'OBS',
          rows: [],
          isObs: true,
          obsText: 'Volta ➔ ${_toTitleCase(current.title)}${multiplier > 1 ? " ${multiplier}x" : ""}',
        ));
      } else {
        finalSections.add(current);
      }
    }

    // 3. Merge consecutive OBS sections
    List<SongSection> mergedSections = [];
    SongSection? activeObs;
    
    for (var section in finalSections) {
      if (section.isObs) {
        if (activeObs == null) {
          activeObs = section;
        } else {
          String nextText = section.obsText ?? "";
          if (nextText.startsWith("Volta ➔ ")) {
            nextText = nextText.substring(8);
          }
          activeObs = SongSection(
            title: 'OBS',
            rows: [],
            isObs: true,
            obsText: '${activeObs.obsText} / $nextText',
          );
        }
      } else {
        if (activeObs != null) {
          mergedSections.add(activeObs);
          activeObs = null;
        }
        mergedSections.add(section);
      }
    }
    if (activeObs != null) {
      mergedSections.add(activeObs);
    }
    
    return mergedSections;
  }

  static _RepetitionResult _detectRepetitions(List<List<String>> measures) {
    if (measures.length < 2) return _RepetitionResult(measures, 1);

    // Try different pattern lengths L from 1 to measures.length / 2
    for (int L = 1; L <= measures.length / 2; L++) {
      if (measures.length % L != 0) continue; // must divide evenly

      bool match = true;
      final pattern = measures.sublist(0, L);

      for (int start = L; start < measures.length; start += L) {
        final chunk = measures.sublist(start, start + L);
        if (!_areMeasuresEqual(pattern, chunk)) {
          match = false;
          break;
        }
      }

      if (match) {
        return _RepetitionResult(pattern, measures.length ~/ L);
      }
    }

    // Also check if it repeats except for the very last chord (resolution chord)
    if (measures.length > 2) {
      for (int L = 1; L <= (measures.length - 1) / 2; L++) {
        if ((measures.length - 1) % L != 0) continue;

        bool match = true;
        final pattern = measures.sublist(0, L);

        for (int start = L; start < measures.length - 1; start += L) {
          final chunk = measures.sublist(start, start + L);
          if (!_areMeasuresEqual(pattern, chunk)) {
            match = false;
            break;
          }
        }

        // Check if the last measure matches the first measure of the pattern
        if (match && _areCellsEqual(measures.last, pattern.first)) {
          return _RepetitionResult(pattern, (measures.length - 1) ~/ L);
        }
      }
    }

    return _RepetitionResult(measures, 1);
  }

  static bool _areMeasuresEqual(List<List<String>> a, List<List<String>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_areCellsEqual(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _areCellsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      // Limpa tudo que não for letra, número, #, b ou /
      final ca = a[i].replaceAll(RegExp(r'[^a-zA-Z0-9#b/]'), '').toLowerCase();
      final cb = b[i].replaceAll(RegExp(r'[^a-zA-Z0-9#b/]'), '').toLowerCase();
      if (ca != cb) {
        return false;
      }
    }
    return true;
  }

  static int _parseRepetition(String? rep) {
    if (rep == null) return 1;
    final clean = rep.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 1;
  }

  static int _getSectionMultiplier(SongSection prev, SongSection current) {
    if (prev.title != current.title) return 0;
    if (prev.rows.isEmpty || current.rows.isEmpty) return 0;
    
    if (_areMeasuresEqual(prev.rows[0].measures, current.rows[0].measures)) {
      return 1;
    }
    
    return 0;
  }

  static String _toTitleCase(String title) {
    return title.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String convertToRoadmapText(ParsedSong parsed) {
    final sb = StringBuffer();
    
    // Meta tags
    if (parsed.title.isNotEmpty) sb.writeln('{title: ${parsed.title}}');
    if (parsed.artist.isNotEmpty) sb.writeln('{artist: ${parsed.artist}}');
    if (parsed.key.isNotEmpty) sb.writeln('{key: ${parsed.key}}');
    if (parsed.video.isNotEmpty) sb.writeln('{video: ${parsed.video}}');
    sb.writeln();

    final sections = SongRoadmapBuilder.build(parsed);
    for (var section in sections) {
      if (section.isObs) {
        sb.writeln('OBS: ${section.obsText}');
        sb.writeln();
        continue;
      }

      // Capitalize section title nicely
      final titleWords = section.title.split(' ').map((w) {
        if (w.isEmpty) return '';
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      }).join(' ');

      sb.writeln('[$titleWords]');
      for (var row in section.rows) {
        if (row.hint != null && row.hint!.isNotEmpty) {
          sb.writeln(row.hint);
        }
        
        final chordLine = row.measures.map((m) => m.join(' ')).join(' | ');
        sb.write(chordLine);
        if (row.repetition != null) {
          sb.write(' ${row.repetition}');
        }
        sb.writeln();
        sb.writeln(); // empty line between rows
      }
    }
    return sb.toString().trim();
  }
}

class _RepetitionResult {
  final List<List<String>> collapsedMeasures;
  final int count;

  _RepetitionResult(this.collapsedMeasures, this.count);
}
