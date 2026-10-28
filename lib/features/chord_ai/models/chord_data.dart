/// Tipos de instrumentos suportados
enum InstrumentType { guitar, piano, ukulele }

/// Modelo de dados de acorde e suas representações nos instrumentos
class ChordInfo {
  final String name;
  final String root;
  final String quality; // 'maj', 'min', '7', 'm7', 'maj7', 'dim', 'aug', 'sus4', etc.
  final List<String> notes;
  final List<GuitarPosition> guitarPositions;
  final List<UkulelePosition> ukulelePositions;

  ChordInfo({
    required this.name,
    required this.root,
    required this.quality,
    required this.notes,
    this.guitarPositions = const [],
    this.ukulelePositions = const [],
  });

  GuitarPosition? get guitarPosition =>
      guitarPositions.isNotEmpty ? guitarPositions.first : null;

  UkulelePosition? get ukulelePosition =>
      ukulelePositions.isNotEmpty ? ukulelePositions.first : null;

  factory ChordInfo.fromJson(Map<String, dynamic> json) {
    return ChordInfo(
      name: json['name'] as String? ?? '',
      root: json['root'] as String? ?? '',
      quality: json['quality'] as String? ?? 'maj',
      notes: (json['notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Posição do acorde no braço do violão (6 cordas: E2, A2, D3, G3, B3, E4)
class GuitarPosition {
  /// Lista de 6 trastes para cada corda (6ª à 1ª).
  /// -1 indica corda abafada/não tocada (x), 0 indica corda solta (o), 1..15 traste.
  final List<int> frets;

  /// Dedos sugeridos para cada corda (0 = nenhum, 1 = indicador, 2 = médio, 3 = anelar, 4 = mínimo)
  final List<int> fingers;

  /// Traste base a partir de onde o diagrama começa (ex: 1 para acordes abertos, 3 para C na 3ª casa)
  final int baseFret;

  /// Se houver pestana, qual o traste da pestana (ou null)
  final int? barreFret;

  const GuitarPosition({
    required this.frets,
    this.fingers = const [0, 0, 0, 0, 0, 0],
    this.baseFret = 1,
    this.barreFret,
  });
}

/// Posição do acorde no Ukulele (4 cordas: G4, C4, E4, A4)
class UkulelePosition {
  /// Lista de 4 trastes para cada corda (4ª à 1ª).
  final List<int> frets;
  final List<int> fingers;
  final int baseFret;
  final int? barreFret;

  const UkulelePosition({
    required this.frets,
    this.fingers = const [0, 0, 0, 0],
    this.baseFret = 1,
    this.barreFret,
  });
}

/// Evento de acorde detectado em um momento específico do tempo
class DetectedChordEvent {
  final String chordName;
  final DateTime timestamp;
  final double confidence; // 0.0 a 1.0

  DetectedChordEvent({
    required this.chordName,
    required this.timestamp,
    required this.confidence,
  });
}
