class SongCollection {
  final String id;
  final String name;

  const SongCollection({
    required this.id,
    required this.name,
  });

  factory SongCollection.fromJson(Map<String, dynamic> json) {
    return SongCollection(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sem Nome',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
