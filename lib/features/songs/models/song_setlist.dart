class SongSetlist {
  final String id;
  final String name;
  final String date;
  final List<SetlistItem> items;

  const SongSetlist({
    required this.id,
    required this.name,
    required this.date,
    required this.items,
  });

  factory SongSetlist.fromJson(Map<String, dynamic> json) {
    return SongSetlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sem Nome',
      date: json['date'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => SetlistItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  SongSetlist copyWith({
    String? id,
    String? name,
    String? date,
    List<SetlistItem>? items,
  }) {
    return SongSetlist(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      items: items ?? this.items,
    );
  }
}

class SetlistItem {
  final String type; // 'song' or 'note'
  final String title;
  final String subtitle; // artist for songs, description/duration for notes
  final String key; // key for songs
  final String duration; // duration/time for notes/pauses
  final String? colorHex;
  final String? songId; // UID da música vinculada

  const SetlistItem({
    required this.type,
    required this.title,
    required this.subtitle,
    this.key = '',
    this.duration = '',
    this.colorHex,
    this.songId,
  });

  factory SetlistItem.fromJson(Map<String, dynamic> json) {
    return SetlistItem(
      type: json['type'] as String? ?? 'song',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      key: json['key'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      colorHex: json['colorHex'] as String?,
      songId: json['songId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'key': key,
      'duration': duration,
      'colorHex': colorHex,
      'songId': songId,
    };
  }

  SetlistItem copyWith({
    String? type,
    String? title,
    String? subtitle,
    String? key,
    String? duration,
    String? colorHex,
    String? songId,
  }) {
    return SetlistItem(
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      key: key ?? this.key,
      duration: duration ?? this.duration,
      colorHex: colorHex ?? this.colorHex,
      songId: songId ?? this.songId,
    );
  }
}
