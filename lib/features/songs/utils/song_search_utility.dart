import '../models/song.dart';

class SongSearchUtility {
  /// Normalizes a string by converting to lowercase and stripping accents / diacritics.
  static String normalize(String text) {
    if (text.isEmpty) return '';
    var str = text.toLowerCase();
    const withAccents = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuucn';

    for (int i = 0; i < withAccents.length; i++) {
      str = str.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return str;
  }

  /// Compacts string by keeping only alphanumeric characters [a-z0-9].
  /// Useful for matches like 'nadatemerei' -> 'nada temerei'.
  static String compact(String text) {
    return normalize(text).replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Extracts pure lyrics from ChordPro text (strips [Chords] and {directives}).
  static String extractLyrics(String chordPro) {
    if (chordPro.isEmpty) return '';
    return chordPro
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\{[^}]*\}'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Checks if a song matches the given search query flexibly.
  static bool matches(Song song, String rawQuery) {
    final query = normalize(rawQuery).trim();
    if (query.isEmpty) return true;

    final queryCompact = compact(query);

    // 1. Direct or Compact match on Title + Artist
    final normTitle = normalize(song.title);
    final normArtist = normalize(song.artist);
    final normTags = normalize(song.tags.join(' '));

    final compactMetadata = compact('${song.title} ${song.artist} ${song.tags.join(' ')}');
    if (queryCompact.isNotEmpty && compactMetadata.contains(queryCompact)) {
      return true;
    }

    // 2. Token-based match (all words must appear in metadata or lyrics)
    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final allInMetadata = tokens.every((token) =>
        normTitle.contains(token) ||
        normArtist.contains(token) ||
        normTags.contains(token));
    if (allInMetadata) return true;

    // 3. Lyrics / Content match (for when user only remembers a phrase or term from the song)
    if (song.content.isNotEmpty) {
      final normLyrics = normalize(extractLyrics(song.content));

      final allInSong = tokens.every((token) =>
          normTitle.contains(token) ||
          normArtist.contains(token) ||
          normTags.contains(token) ||
          normLyrics.contains(token));
      if (allInSong) return true;

      // Compact lyrics check for joined words in lyrics
      if (queryCompact.length >= 4) {
        final compactLyrics = compact(normLyrics);
        if (compactLyrics.contains(queryCompact)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Calculates a relevance score for sorting search results.
  /// Higher score = more relevant result.
  static int relevanceScore(Song song, String rawQuery) {
    final query = normalize(rawQuery).trim();
    if (query.isEmpty) return 0;

    final queryCompact = compact(query);
    final normTitle = normalize(song.title);
    final normArtist = normalize(song.artist);
    final compactTitle = compact(song.title);

    // Exact title match
    if (normTitle == query || compactTitle == queryCompact) {
      return 1000;
    }

    // Title starts with query
    if (normTitle.startsWith(query) || (queryCompact.isNotEmpty && compactTitle.startsWith(queryCompact))) {
      return 800;
    }

    // Title contains full query
    if (normTitle.contains(query) || (queryCompact.isNotEmpty && compactTitle.contains(queryCompact))) {
      return 600;
    }

    // Artist starts with or contains query
    if (normArtist.startsWith(query)) {
      return 450;
    }
    if (normArtist.contains(query)) {
      return 400;
    }

    // All tokens in title
    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isNotEmpty && tokens.every((t) => normTitle.contains(t))) {
      return 350;
    }

    // Tokens split between title and artist
    if (tokens.isNotEmpty && tokens.every((t) => normTitle.contains(t) || normArtist.contains(t))) {
      return 250;
    }

    // Lyrics match
    if (song.content.isNotEmpty) {
      final normLyrics = normalize(extractLyrics(song.content));
      if (normLyrics.contains(query)) {
        return 150;
      }
      if (tokens.isNotEmpty && tokens.every((t) => normLyrics.contains(t))) {
        return 100;
      }
    }

    return 50;
  }

  /// Filters and ranks a list of songs according to the query.
  static List<Song> filterAndRank(List<Song> songs, String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return List<Song>.from(songs)..sort((a, b) => normalize(a.title).compareTo(normalize(b.title)));
    }

    final matched = songs.where((s) => matches(s, query)).toList();

    matched.sort((a, b) {
      final scoreA = relevanceScore(a, query);
      final scoreB = relevanceScore(b, query);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // higher score first
      }
      return normalize(a.title).compareTo(normalize(b.title));
    });

    return matched;
  }
}
