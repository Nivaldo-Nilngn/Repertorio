import '../widgets/scrolling_waveform_timeline.dart';

class SetlistCategory {
  final String id;
  final String title;
  final String subtitle;
  final String icon;

  const SetlistCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class MeasureBeat {
  final int measureNumber;
  final double startSeconds;
  final double durationSeconds;
  final String chord;

  const MeasureBeat({
    required this.measureNumber,
    required this.startSeconds,
    required this.durationSeconds,
    required this.chord,
  });
}

class FeaturedSong {
  final String id;
  final String title;
  final String artist;
  final String categoryId;
  final String key;
  final int bpm;
  final int durationSeconds;
  final String thumbnailUrl;
  final String jamsCount;
  final List<ChordMarker> chordMarkers;
  final List<MeasureBeat> measures;

  const FeaturedSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.categoryId,
    required this.key,
    required this.bpm,
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.jamsCount,
    required this.chordMarkers,
    required this.measures,
  });

  String get formattedDuration {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class SetlistRepository {
  static const List<SetlistCategory> categories = [
    SetlistCategory(
      id: 'featured',
      title: '🌟 Em Destaque',
      subtitle: 'As músicas mais tocadas no momento',
      icon: 'star',
    ),
    SetlistCategory(
      id: 'brazil',
      title: '🇧🇷 Brasil & MPB',
      subtitle: 'Clássicos nacionais, MPB e Pop Rock',
      icon: 'flag',
    ),
    SetlistCategory(
      id: 'campfire',
      title: '🔥 Violão & Campfire',
      subtitle: 'Músicas acústicas perfeitas para tocar junto',
      icon: 'fire',
    ),
    SetlistCategory(
      id: 'piano',
      title: '🎹 Piano & Teclado',
      subtitle: 'Arranjos lendários para teclas',
      icon: 'piano',
    ),
    SetlistCategory(
      id: 'easy',
      title: '🟢 Cifras Fáceis',
      subtitle: 'Ideal para iniciantes (3 a 4 acordes básicos)',
      icon: 'smile',
    ),
    SetlistCategory(
      id: 'rock',
      title: '🎸 Rock Legends',
      subtitle: 'Hinos imortais da história do Rock',
      icon: 'guitar',
    ),
  ];

  static FeaturedSong _createFeaturedSong({
    required String id,
    required String title,
    required String artist,
    required String categoryId,
    required String key,
    required int bpm,
    required int durationSeconds,
    required String jamsCount,
  }) {
    return FeaturedSong(
      id: id,
      title: title,
      artist: artist,
      categoryId: categoryId,
      key: key,
      bpm: bpm,
      durationSeconds: durationSeconds,
      thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
      jamsCount: jamsCount,
      chordMarkers: const [],
      measures: const [],
    );
  }

  static final List<FeaturedSong> allSongs = [
    // 1. Gabriela Rocha - Atos 2
    _createFeaturedSong(
      id: 'WWrU6LC_4ho',
      title: 'Atos 2',
      artist: 'Gabriela Rocha',
      categoryId: 'featured',
      key: 'G',
      bpm: 79,
      durationSeconds: 317,
      jamsCount: '3.1M jams',
    ),

    // 2. Nando Reis - Por Onde Andei
    _createFeaturedSong(
      id: '0H5y-GDTrHc',
      title: 'Por Onde Andei',
      artist: 'Nando Reis',
      categoryId: 'brazil',
      key: 'G',
      bpm: 84,
      durationSeconds: 252,
      jamsCount: '1.8M jams',
    ),

    // 3. Queen - Bohemian Rhapsody
    _createFeaturedSong(
      id: 'fJ9rUzIMcZQ',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      categoryId: 'featured',
      key: 'Bb',
      bpm: 72,
      durationSeconds: 355,
      jamsCount: '3.4M jams',
    ),

    // 4. Legião Urbana - Pais e Filhos
    _createFeaturedSong(
      id: 'sfixHYBWaiU',
      title: 'Pais e Filhos',
      artist: 'Legião Urbana',
      categoryId: 'brazil',
      key: 'C',
      bpm: 90,
      durationSeconds: 308,
      jamsCount: '2.1M jams',
    ),

    // 5. The Beatles - Let It Be
    _createFeaturedSong(
      id: 'QDYfEBY9NM4',
      title: 'Let It Be',
      artist: 'The Beatles',
      categoryId: 'featured',
      key: 'C',
      bpm: 73,
      durationSeconds: 243,
      jamsCount: '4.2M jams',
    ),

    // 6. John Lennon - Imagine
    _createFeaturedSong(
      id: 'rAn-AWXtHv0',
      title: 'Imagine',
      artist: 'John Lennon',
      categoryId: 'piano',
      key: 'C',
      bpm: 76,
      durationSeconds: 233,
      jamsCount: '2.9M jams',
    ),

    // 7. Ed Sheeran - Perfect
    _createFeaturedSong(
      id: '2Vv-BfVoq4g',
      title: 'Perfect',
      artist: 'Ed Sheeran',
      categoryId: 'featured',
      key: 'Ab',
      bpm: 95,
      durationSeconds: 263,
      jamsCount: '5.1M jams',
    ),

    // 8. Oasis - Wonderwall
    _createFeaturedSong(
      id: 'bx1Bh8ZvH84',
      title: 'Wonderwall',
      artist: 'Oasis',
      categoryId: 'campfire',
      key: 'Em',
      bpm: 87,
      durationSeconds: 278,
      jamsCount: '4.8M jams',
    ),

    // 9. Eagles - Hotel California
    _createFeaturedSong(
      id: '09839DpTctU',
      title: 'Hotel California',
      artist: 'Eagles',
      categoryId: 'rock',
      key: 'Bm',
      bpm: 75,
      durationSeconds: 390,
      jamsCount: '3.7M jams',
    ),

    // 10. Ben E. King - Stand By Me (Easy)
    _createFeaturedSong(
      id: 'hwZNL7QVJjE',
      title: 'Stand By Me',
      artist: 'Ben E. King',
      categoryId: 'easy',
      key: 'A',
      bpm: 118,
      durationSeconds: 180,
      jamsCount: '2.5M jams',
    ),

    // 11. The Cranberries - Zombie (Easy)
    _createFeaturedSong(
      id: '6Ejga4kJUts',
      title: 'Zombie',
      artist: 'The Cranberries',
      categoryId: 'easy',
      key: 'Em',
      bpm: 84,
      durationSeconds: 306,
      jamsCount: '3.0M jams',
    ),

    // 12. Coldplay - Yellow
    _createFeaturedSong(
      id: 'yKNxeF4KMsY',
      title: 'Yellow',
      artist: 'Coldplay',
      categoryId: 'campfire',
      key: 'B',
      bpm: 87,
      durationSeconds: 269,
      jamsCount: '3.2M jams',
    ),

    // 13. Alceu Valença - Anunciação
    _createFeaturedSong(
      id: 'OR74idpsweg',
      title: 'Anunciação',
      artist: 'Alceu Valença',
      categoryId: 'brazil',
      key: 'C',
      bpm: 118,
      durationSeconds: 204,
      jamsCount: '1.4M jams',
    ),

    // 14. Adele - Someone Like You
    _createFeaturedSong(
      id: 'hLQl3WQQoQ0',
      title: 'Someone Like You',
      artist: 'Adele',
      categoryId: 'piano',
      key: 'A',
      bpm: 67,
      durationSeconds: 285,
      jamsCount: '2.7M jams',
    ),

    // 15. Vance Joy - Riptide (Easy)
    _createFeaturedSong(
      id: 'uJ_1HMAGb4k',
      title: 'Riptide',
      artist: 'Vance Joy',
      categoryId: 'easy',
      key: 'Am',
      bpm: 102,
      durationSeconds: 204,
      jamsCount: '3.9M jams',
    ),
  ];

  /// Cria uma estrutura limpa para o vídeo sem dados mocados (acordes virão 100% da IA)
  static FeaturedSong createSongForVideo({
    required String id,
    required String title,
    required String artist,
    int durationSeconds = 240,
    String key = 'C',
    int bpm = 80,
  }) {
    return FeaturedSong(
      id: id,
      title: title,
      artist: artist,
      categoryId: 'ai',
      key: key,
      bpm: bpm,
      durationSeconds: durationSeconds,
      thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
      jamsCount: 'Análise IA pura',
      chordMarkers: const [],
      measures: const [],
    );
  }

  /// Mantido para compatibilidade, retornando modelo puro sem acordes mocados
  static FeaturedSong generateSongForVideo({
    required String id,
    required String title,
    required String artist,
    int durationSeconds = 240,
    String? key,
    int? bpm,
  }) {
    return createSongForVideo(
      id: id,
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
      key: key ?? 'C',
      bpm: bpm ?? 80,
    );
  }

  /// Analisador inteligente de texto do Cifra Club / Cifras
  /// Extrai Tom e acordes reais digitados/colados pelo usuário (sem gerar dados falsos)
  static FeaturedSong parseCifraClubText({
    required String text,
    required String id,
    required String title,
    required String artist,
    int durationSeconds = 344,
    int bpm = 68,
  }) {
    final chordRegex = RegExp(
        r"^[A-G][b#]?(?:m|maj|min|dim|aug|sus|add)?[0-9]*(?:/[A-G][b#]?)?$");
    final tomRegex =
        RegExp(r"Tom:\s*([A-G][b#]?(?:m)?)", caseSensitive: false);

    String detectedKey = 'C';
    final tomMatch = tomRegex.firstMatch(text);
    if (tomMatch != null) {
      detectedKey = tomMatch.group(1) ?? 'C';
    }

    final lines = text.split('\n');
    final chords = <String>[];

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Remove anotações entre colchetes como [Intro], [Primeira Parte], [Refrão]
      if (trimmed.startsWith('[')) {
        trimmed = trimmed.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      }
      if (trimmed.isEmpty) continue;

      final rawTokens = trimmed.split(RegExp(r'\s+'));
      final tokens = rawTokens
          .map((t) => t.replaceAll(RegExp(r'^[(\[{]+|[)\]}]+$'), '').trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (tokens.isEmpty) continue;

      final chordTokens = tokens.where((t) => chordRegex.hasMatch(t)).toList();
      if (chordTokens.isNotEmpty &&
          (chordTokens.length == tokens.length ||
              chordTokens.length > tokens.length / 2)) {
        chords.addAll(chordTokens);
      }
    }

    // Se nenhum acorde foi identificado no texto colado, retorna sem acordes mocados
    if (chords.isEmpty) {
      return FeaturedSong(
        id: id,
        title: title,
        artist: artist,
        categoryId: 'cifra_club',
        key: detectedKey,
        bpm: bpm,
        durationSeconds: durationSeconds,
        thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
        jamsCount: 'Texto sem acordes',
        chordMarkers: const [],
        measures: const [],
      );
    }

    final secondsPerMeasure = (60.0 / (bpm > 0 ? bpm : 72)) * 4;
    final List<ChordMarker> markers = [];
    final List<MeasureBeat> measures = [];
    double currentSec = 0.0;
    int idx = 0;

    while (currentSec < durationSeconds && idx < chords.length) {
      final chord = chords[idx];
      markers.add(ChordMarker(currentSec, chord));
      measures.add(
        MeasureBeat(
          measureNumber: idx + 1,
          startSeconds: currentSec,
          durationSeconds: secondsPerMeasure,
          chord: chord,
        ),
      );
      currentSec += secondsPerMeasure;
      idx++;
    }

    return FeaturedSong(
      id: id,
      title: title,
      artist: artist,
      categoryId: 'cifra_club',
      key: detectedKey,
      bpm: bpm,
      durationSeconds: durationSeconds,
      thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
      jamsCount: 'Cifra Club Importada',
      chordMarkers: markers,
      measures: measures,
    );
  }

  /// Busca música nas setlists cadastradas ou cria modelo limpo pronto para análise IA
  static FeaturedSong findOrGenerateSongForVideo({
    required String id,
    required String title,
    required String artist,
    int durationSeconds = 240,
  }) {
    final lowerTitle = title.toLowerCase();

    for (final song in allSongs) {
      if (song.id == id ||
          lowerTitle.contains(song.title.toLowerCase()) ||
          song.title.toLowerCase().contains(lowerTitle)) {
        return song;
      }
    }

    return createSongForVideo(
      id: id,
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
    );
  }

  /// Transpõe um acorde por N semitons (ex: C + 2 = D, Am + 1 = Bbm)
  static String transposeChord(String chord, int semitones) {
    if (semitones == 0 || chord.isEmpty) return chord;

    const sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const flats  = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

    // Se tiver barra (slash chord, ex: C/E)
    if (chord.contains('/')) {
      final parts = chord.split('/');
      return '${transposeChord(parts[0], semitones)}/${transposeChord(parts[1], semitones)}';
    }

    // Identifica nota fundamental
    String root = '';
    String suffix = '';

    if (chord.length >= 2 && (chord[1] == '#' || chord[1] == 'b')) {
      root = chord.substring(0, 2);
      suffix = chord.substring(2);
    } else {
      root = chord.substring(0, 1);
      suffix = chord.substring(1);
    }

    int idx = sharps.indexOf(root);
    if (idx == -1) idx = flats.indexOf(root);
    if (idx == -1) return chord; // Not recognized, return as is

    int newIdx = (idx + semitones) % 12;
    if (newIdx < 0) newIdx += 12;

    final newRoot = (root.contains('b') || semitones < 0) ? flats[newIdx] : sharps[newIdx];
    return '$newRoot$suffix';
  }
}
