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
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Sem Título',
      artist: json['artist'] as String? ?? 'Artista Desconhecido',
      key: json['key'] as String? ?? 'C',
      bpm: json['bpm'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      folderId: json['folderId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      isFavorite: json['isFavorite'] as bool? ?? false,
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
    );
  }
}
