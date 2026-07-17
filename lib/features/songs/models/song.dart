class Song {
  final String id;
  final String title;
  final String artist;
  final String key;
  final int bpm;
  final String content; // ChordPro text
  final String? folderId;
  final List<String> tags;
  final bool isFavorite;
  final int transposeSteps;
  final double? viewerFontSize;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.key,
    required this.bpm,
    required this.content,
    this.folderId,
    this.tags = const [],
    this.isFavorite = false,
    this.transposeSteps = 0,
    this.viewerFontSize,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    int parsedBpm = 0;
    if (json['bpm'] != null) {
      if (json['bpm'] is int) {
        parsedBpm = json['bpm'] as int;
      } else if (json['bpm'] is String) {
        parsedBpm = int.tryParse(json['bpm'] as String) ?? 0;
      }
    }

    List<String> parsedTags = [];
    if (json['tags'] != null) {
      if (json['tags'] is List) {
        parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
      } else if (json['tags'] is String) {
        parsedTags = [json['tags'] as String];
      }
    }

    return Song(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sem Título',
      artist: json['artist']?.toString() ?? 'Artista Desconhecido',
      key: json['key']?.toString() ?? 'C',
      bpm: parsedBpm,
      content: json['content']?.toString() ?? '',
      folderId: json['folderId']?.toString(),
      tags: parsedTags,
      isFavorite: json['isFavorite'] == true || json['isFavorite'] == 'true',
      transposeSteps: json['transposeSteps'] is int 
          ? json['transposeSteps'] as int 
          : int.tryParse(json['transposeSteps']?.toString() ?? '0') ?? 0,
      viewerFontSize: json['viewerFontSize'] is num 
          ? (json['viewerFontSize'] as num).toDouble() 
          : double.tryParse(json['viewerFontSize']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'key': key,
      'bpm': bpm,
      'content': content,
      'folderId': folderId,
      'tags': tags,
      'isFavorite': isFavorite,
      'transposeSteps': transposeSteps,
      'viewerFontSize': viewerFontSize,
    };
  }

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? key,
    int? bpm,
    String? content,
    String? folderId,
    List<String>? tags,
    bool? isFavorite,
    int? transposeSteps,
    double? viewerFontSize,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      key: key ?? this.key,
      bpm: bpm ?? this.bpm,
      content: content ?? this.content,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      transposeSteps: transposeSteps ?? this.transposeSteps,
      viewerFontSize: viewerFontSize ?? this.viewerFontSize,
    );
  }
}
