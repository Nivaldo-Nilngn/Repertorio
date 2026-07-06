class ParsedSong {
  final String title;
  final String artist;
  final String key;
  final String video;
  final List<SongLine> lines;

  ParsedSong({
    required this.title,
    required this.artist,
    required this.key,
    required this.video,
    required this.lines,
  });
}

class SongLine {
  final String lyrics;
  final List<ChordPosition> chords;
  final String? type; // Ex: 'comment'

  SongLine({required this.lyrics, required this.chords, this.type});
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
    List<SongLine> lines = [];

    final regex = RegExp(r'\[(.*?)\]');

    for (var rawLine in chordProText.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        lines.add(SongLine(lyrics: '', chords: []));
        continue;
      }

      // Metadata directives (e.g., {title: Amazing Grace})
      if (line.startsWith('{') && line.endsWith('}')) {
        final content = line.substring(1, line.length - 1);
        final parts = content.split(':');
        if (parts.length >= 2) {
          final directive = parts[0].trim().toLowerCase();
          final value = parts.sublist(1).join(':').trim();

          if (directive == 'title' || directive == 't') title = value;
          else if (directive == 'artist') artist = value;
          else if (directive == 'key') key = value;
          else if (directive == 'video') video = value;
          else if (directive == 'c' || directive == 'comment') {
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
        
        // If it's too long, has spaces, or matches known section names, treat as lyrics/section marker.
        if (chordText.contains(' ') || chordText.length > 8 || lowerText == 'intro' || lowerText == 'solo' || lowerText == 'refrão' || lowerText == 'refrao' || lowerText == 'chorus' || lowerText == 'verse') {
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

      lines.add(SongLine(lyrics: lyrics, chords: chords));
    }

    return ParsedSong(
      title: title,
      artist: artist,
      key: key,
      video: video,
      lines: lines,
    );
  }
}
