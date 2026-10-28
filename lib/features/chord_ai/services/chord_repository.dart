import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/chord_data.dart';

class ChordRepository {
  static final ChordRepository _instance = ChordRepository._internal();
  factory ChordRepository() => _instance;
  ChordRepository._internal();

  final List<String> chromaticNotes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  final Map<String, String> enharmonics = {
    'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
  };

  /// Dicionário completo de acordes em memória
  final Map<String, ChordInfo> _chordsMap = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<ChordInfo> get allChords => _chordsMap.values.toList();

  /// Inicializa o repositório carregando os dados do asset e posições pré-computadas
  Future<void> init() async {
    if (_isLoaded) return;

    // Popula posições padrão de Violão e Ukulele para os acordes mais populares
    _populateStandardPositions();

    try {
      final jsonString = await rootBundle.loadString('assets/data/chords_list.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      for (final item in jsonList) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String? ?? '';
          if (name.isEmpty) continue;

          final notes = (item['notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          final parts = _parseChordName(name);

          // Se já temos posições de violão/ukulele para este acorde, mesclamos
          final existing = _chordsMap[name];
          _chordsMap[name] = ChordInfo(
            name: name,
            root: parts.$1,
            quality: parts.$2,
            notes: notes,
            guitarPositions: existing?.guitarPositions ?? _generateFallbackGuitarPositions(parts.$1, parts.$2),
            ukulelePositions: existing?.ukulelePositions ?? _generateFallbackUkulelePositions(parts.$1, parts.$2),
          );
        }
      }
      _isLoaded = true;
    } catch (e) {
      // Se falhar o load do asset, garante que os padrões continuem ativos
      _isLoaded = true;
    }
  }

  /// Retorna informações do acorde pelo nome (ex: "C", "Am", "G7")
  ChordInfo getChord(String chordName) {
    final clean = chordName.trim();
    if (_chordsMap.containsKey(clean)) {
      return _chordsMap[clean]!;
    }

    // Tenta normalizar sustenido/bemol
    final normalized = _normalizeChordName(clean);
    if (_chordsMap.containsKey(normalized)) {
      return _chordsMap[normalized]!;
    }

    // Se for slash chord (ex: G/B, D/F#, G9/B, C/E)
    if (clean.contains('/')) {
      final parts = clean.split('/');
      final baseChordName = parts[0].trim();
      final bassNote = parts[1].trim();

      final baseChord = getChord(baseChordName);
      final notes = List<String>.from(baseChord.notes);
      if (!notes.contains(bassNote)) {
        notes.insert(0, bassNote);
      }

      return ChordInfo(
        name: clean,
        root: baseChord.root,
        quality: baseChord.quality,
        notes: notes,
        guitarPositions: baseChord.guitarPositions,
        ukulelePositions: baseChord.ukulelePositions,
      );
    }

    // Se não encontrou, gera dinamicamente
    final parts = _parseChordName(clean);
    final notes = _calculateNotes(parts.$1, parts.$2);
    final chord = ChordInfo(
      name: clean,
      root: parts.$1,
      quality: parts.$2,
      notes: notes,
      guitarPositions: _generateFallbackGuitarPositions(parts.$1, parts.$2),
      ukulelePositions: _generateFallbackUkulelePositions(parts.$1, parts.$2),
    );
    _chordsMap[clean] = chord;
    return chord;
  }

  /// Busca acordes por termo (ex: "C", "min", "7")
  List<ChordInfo> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _chordsMap.values.take(50).toList();
    return _chordsMap.values
        .where((c) => c.name.toLowerCase().contains(q))
        .take(50)
        .toList();
  }

  /// Normaliza sustenidos e bemóis
  String _normalizeChordName(String name) {
    for (final entry in enharmonics.entries) {
      if (name.startsWith(entry.key)) {
        return name.replaceFirst(entry.key, entry.value);
      }
    }
    return name;
  }

  /// Divide o acorde em (Root, Quality)
  (String, String) _parseChordName(String name) {
    if (name.isEmpty) return ('C', 'maj');
    String root = name.substring(0, 1).toUpperCase();
    int qualityStart = 1;

    if (name.length > 1 && (name[1] == '#' || name[1] == 'b')) {
      root = name.substring(0, 2);
      qualityStart = 2;
    }

    String quality = name.substring(qualityStart);
    if (quality.isEmpty) quality = 'maj';
    return (root, quality);
  }

  /// Calcula as notas de qualquer acorde baseado na teoria musical
  List<String> _calculateNotes(String root, String quality) {
    final rootIndex = chromaticNotes.indexOf(root);
    if (rootIndex == -1) return [root];

    // Intervalos em semitons a partir da tônica
    List<int> intervals;
    final q = quality.toLowerCase();
    if (q == 'maj' || q == 'major' || q == '') {
      intervals = [0, 4, 7]; // T, 3M, 5J
    } else if (q == 'm' || q == 'min' || q == 'minor') {
      intervals = [0, 3, 7]; // T, 3m, 5J
    } else if (q == '7' || q == 'dom7') {
      intervals = [0, 4, 7, 10]; // T, 3M, 5J, 7m
    } else if (q == 'm7' || q == 'min7') {
      intervals = [0, 3, 7, 10]; // T, 3m, 5J, 7m
    } else if (q == 'maj7' || q == '7m') {
      intervals = [0, 4, 7, 11]; // T, 3M, 5J, 7M
    } else if (q == '4' || q == 'sus4') {
      intervals = [0, 5, 7]; // T, 4J, 5J (D4, G4)
    } else if (q == 'sus2') {
      intervals = [0, 2, 7]; // T, 2M, 5J
    } else if (q == '9' || q == 'add9') {
      intervals = [0, 2, 4, 7]; // T, 2M, 3M, 5J (C9, Cadd9)
    } else if (q == 'm9') {
      intervals = [0, 2, 3, 7, 10]; // T, 2M, 3m, 5J, 7m
    } else if (q == '6') {
      intervals = [0, 4, 7, 9]; // T, 3M, 5J, 6M
    } else if (q == 'm6') {
      intervals = [0, 3, 7, 9]; // T, 3m, 5J, 6M
    } else if (q == 'dim' || q == 'dim7') {
      intervals = [0, 3, 6, 9]; // T, 3m, 5dim, 7dim
    } else if (q == 'aug' || q == '+') {
      intervals = [0, 4, 8]; // T, 3M, 5Aum
    } else {
      intervals = [0, 4, 7];
    }

    return intervals.map((i) => chromaticNotes[(rootIndex + i) % 12]).toList();
  }

  /// Posições clássicas detalhadas de violão e ukulele para os acordes mais tocados
  void _populateStandardPositions() {
    _addChord('C', ['C', 'E', 'G'],
      guitar: [
        const GuitarPosition(frets: [-1, 3, 2, 0, 1, 0], fingers: [0, 3, 2, 0, 1, 0]),
        const GuitarPosition(frets: [-1, 3, 5, 5, 5, 3], fingers: [0, 1, 2, 3, 4, 1], baseFret: 3, barreFret: 3),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 0, 0, 3], fingers: [0, 0, 0, 3]),
      ],
    );

    _addChord('Cm', ['C', 'D#', 'G'],
      guitar: [
        const GuitarPosition(frets: [-1, 3, 5, 5, 4, 3], fingers: [0, 1, 3, 4, 2, 1], baseFret: 3, barreFret: 3),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 3, 3, 3], fingers: [0, 1, 2, 3]),
      ],
    );

    _addChord('C7', ['C', 'E', 'G', 'A#'],
      guitar: [
        const GuitarPosition(frets: [-1, 3, 2, 3, 1, 0], fingers: [0, 3, 2, 4, 1, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 0, 0, 1], fingers: [0, 0, 0, 1]),
      ],
    );

    _addChord('D', ['D', 'F#', 'A'],
      guitar: [
        const GuitarPosition(frets: [-1, -1, 0, 2, 3, 2], fingers: [0, 0, 0, 1, 3, 2]),
      ],
      ukulele: [
        const UkulelePosition(frets: [2, 2, 2, 0], fingers: [1, 2, 3, 0]),
      ],
    );

    _addChord('Dm', ['D', 'F', 'A'],
      guitar: [
        const GuitarPosition(frets: [-1, -1, 0, 2, 3, 1], fingers: [0, 0, 0, 2, 3, 1]),
      ],
      ukulele: [
        const UkulelePosition(frets: [2, 2, 1, 0], fingers: [2, 3, 1, 0]),
      ],
    );

    _addChord('D7', ['D', 'F#', 'A', 'C'],
      guitar: [
        const GuitarPosition(frets: [-1, -1, 0, 2, 1, 2], fingers: [0, 0, 0, 2, 1, 3]),
      ],
      ukulele: [
        const UkulelePosition(frets: [2, 0, 2, 0], fingers: [1, 0, 2, 0]),
      ],
    );

    _addChord('E', ['E', 'G#', 'B'],
      guitar: [
        const GuitarPosition(frets: [0, 2, 2, 1, 0, 0], fingers: [0, 2, 3, 1, 0, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [4, 4, 4, 2], fingers: [2, 3, 4, 1], baseFret: 2),
      ],
    );

    _addChord('Em', ['E', 'G', 'B'],
      guitar: [
        const GuitarPosition(frets: [0, 2, 2, 0, 0, 0], fingers: [0, 2, 3, 0, 0, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 4, 3, 2], fingers: [0, 3, 2, 1]),
      ],
    );

    _addChord('E7', ['E', 'G#', 'B', 'D'],
      guitar: [
        const GuitarPosition(frets: [0, 2, 0, 1, 0, 0], fingers: [0, 2, 0, 1, 0, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [1, 2, 0, 2], fingers: [1, 2, 0, 3]),
      ],
    );

    _addChord('F', ['F', 'A', 'C'],
      guitar: [
        const GuitarPosition(frets: [1, 3, 3, 2, 1, 1], fingers: [1, 3, 4, 2, 1, 1], baseFret: 1, barreFret: 1),
      ],
      ukulele: [
        const UkulelePosition(frets: [2, 0, 1, 0], fingers: [2, 0, 1, 0]),
      ],
    );

    _addChord('Fm', ['F', 'G#', 'C'],
      guitar: [
        const GuitarPosition(frets: [1, 3, 3, 1, 1, 1], fingers: [1, 3, 4, 1, 1, 1], baseFret: 1, barreFret: 1),
      ],
      ukulele: [
        const UkulelePosition(frets: [1, 0, 1, 3], fingers: [1, 0, 2, 4]),
      ],
    );

    _addChord('G', ['G', 'B', 'D'],
      guitar: [
        const GuitarPosition(frets: [3, 2, 0, 0, 0, 3], fingers: [2, 1, 0, 0, 0, 3]),
        const GuitarPosition(frets: [3, 2, 0, 0, 3, 3], fingers: [2, 1, 0, 0, 3, 4]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 3, 2], fingers: [0, 1, 3, 2]),
      ],
    );

    _addChord('Gm', ['G', 'A#', 'D'],
      guitar: [
        const GuitarPosition(frets: [3, 5, 5, 3, 3, 3], fingers: [1, 3, 4, 1, 1, 1], baseFret: 3, barreFret: 3),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 3, 1], fingers: [0, 2, 3, 1]),
      ],
    );

    _addChord('G7', ['G', 'B', 'D', 'F'],
      guitar: [
        const GuitarPosition(frets: [3, 2, 0, 0, 0, 1], fingers: [3, 2, 0, 0, 0, 1]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 1, 2], fingers: [0, 2, 1, 3]),
      ],
    );

    _addChord('A', ['A', 'C#', 'E'],
      guitar: [
        const GuitarPosition(frets: [-1, 0, 2, 2, 2, 0], fingers: [0, 0, 1, 2, 3, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [2, 1, 0, 0], fingers: [2, 1, 0, 0]),
      ],
    );

    _addChord('Am', ['A', 'C', 'E'],
      guitar: [
        const GuitarPosition(frets: [-1, 0, 2, 2, 1, 0], fingers: [0, 0, 2, 3, 1, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [2, 0, 0, 0], fingers: [1, 0, 0, 0]),
      ],
    );

    _addChord('A7', ['A', 'C#', 'E', 'G'],
      guitar: [
        const GuitarPosition(frets: [-1, 0, 2, 0, 2, 0], fingers: [0, 0, 2, 0, 3, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 1, 0, 0], fingers: [0, 1, 0, 0]),
      ],
    );

    _addChord('B', ['B', 'D#', 'F#'],
      guitar: [
        const GuitarPosition(frets: [-1, 2, 4, 4, 4, 2], fingers: [0, 1, 2, 3, 4, 1], baseFret: 2, barreFret: 2),
      ],
      ukulele: [
        const UkulelePosition(frets: [4, 3, 2, 2], fingers: [3, 2, 1, 1], baseFret: 2, barreFret: 2),
      ],
    );

    _addChord('Bm', ['B', 'D', 'F#'],
      guitar: [
        const GuitarPosition(frets: [-1, 2, 4, 4, 3, 2], fingers: [0, 1, 3, 4, 2, 1], baseFret: 2, barreFret: 2),
      ],
      ukulele: [
        const UkulelePosition(frets: [4, 2, 2, 2], fingers: [3, 1, 1, 1], baseFret: 2, barreFret: 2),
      ],
    );

    _addChord('B7', ['B', 'D#', 'F#', 'A'],
      guitar: [
        const GuitarPosition(frets: [-1, 2, 1, 2, 0, 2], fingers: [0, 2, 1, 3, 0, 4]),
      ],
      ukulele: [
        const UkulelePosition(frets: [2, 3, 2, 2], fingers: [1, 2, 1, 1], baseFret: 2, barreFret: 2),
      ],
    );

    // Acordes modernos frequentes no Cifra Club (Atos 2, Worship, MPB, Pop)
    _addChord('Em7', ['E', 'G', 'B', 'D'],
      guitar: [
        const GuitarPosition(frets: [0, 2, 2, 0, 3, 0], fingers: [0, 1, 2, 0, 3, 0]),
        const GuitarPosition(frets: [0, 2, 0, 0, 0, 0], fingers: [0, 1, 0, 0, 0, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 0, 2], fingers: [0, 1, 0, 2]),
      ],
    );

    _addChord('C9', ['C', 'D', 'E', 'G'],
      guitar: [
        const GuitarPosition(frets: [-1, 3, 2, 0, 3, 3], fingers: [0, 2, 1, 0, 3, 4]),
        const GuitarPosition(frets: [-1, 3, 2, 0, 3, 0], fingers: [0, 2, 1, 0, 3, 0]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 0, 3], fingers: [0, 1, 0, 2]),
      ],
    );

    _addChord('Cadd9', ['C', 'D', 'E', 'G'],
      guitar: [
        const GuitarPosition(frets: [-1, 3, 2, 0, 3, 3], fingers: [0, 2, 1, 0, 3, 4]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 0, 3], fingers: [0, 1, 0, 2]),
      ],
    );

    _addChord('D4', ['D', 'G', 'A'],
      guitar: [
        const GuitarPosition(frets: [-1, -1, 0, 2, 3, 3], fingers: [0, 0, 0, 1, 2, 4]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 3, 0], fingers: [0, 1, 2, 0]),
      ],
    );

    _addChord('Dsus4', ['D', 'G', 'A'],
      guitar: [
        const GuitarPosition(frets: [-1, -1, 0, 2, 3, 3], fingers: [0, 0, 0, 1, 2, 4]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 3, 0], fingers: [0, 1, 2, 0]),
      ],
    );

    _addChord('G9/B', ['B', 'D', 'G', 'A'],
      guitar: [
        const GuitarPosition(frets: [-1, 2, 0, 2, 3, 3], fingers: [0, 1, 0, 2, 3, 4]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 3, 0], fingers: [0, 1, 2, 0]),
      ],
    );

    _addChord('G/B', ['B', 'D', 'G'],
      guitar: [
        const GuitarPosition(frets: [-1, 2, 0, 0, 3, 3], fingers: [0, 1, 0, 0, 3, 4]),
      ],
      ukulele: [
        const UkulelePosition(frets: [0, 2, 3, 2], fingers: [0, 1, 3, 2]),
      ],
    );

    _addChord('D/F#', ['F#', 'A', 'D'],
      guitar: [
        const GuitarPosition(frets: [2, 0, 0, 2, 3, 2], fingers: [1, 0, 0, 2, 4, 3]),
      ],
      ukulele: [
        const UkulelePosition(frets: [2, 2, 2, 0], fingers: [1, 2, 3, 0]),
      ],
    );
  }

  void _addChord(String name, List<String> notes, {required List<GuitarPosition> guitar, required List<UkulelePosition> ukulele}) {
    final parts = _parseChordName(name);
    _chordsMap[name] = ChordInfo(
      name: name,
      root: parts.$1,
      quality: parts.$2,
      notes: notes,
      guitarPositions: guitar,
      ukulelePositions: ukulele,
    );
  }

  /// Gera posições algorítmicas no violão com pestana móvel estilo CAGED
  List<GuitarPosition> _generateFallbackGuitarPositions(String root, String quality) {
    final rootIdx = chromaticNotes.indexOf(root);
    if (rootIdx == -1) return [const GuitarPosition(frets: [-1, -1, -1, -1, -1, -1])];

    final isMinor = quality.toLowerCase().startsWith('m');
    // Fórmulas baseadas na 6ª corda (E shape)
    // E está no índice 4. Traste = (rootIdx - 4 + 12) % 12
    final fretE = (rootIdx - 4 + 12) % 12;
    final baseFret = fretE == 0 ? 12 : fretE;

    if (isMinor) {
      return [
        GuitarPosition(
          frets: [baseFret, baseFret + 2, baseFret + 2, baseFret, baseFret, baseFret],
          fingers: [1, 3, 4, 1, 1, 1],
          baseFret: baseFret,
          barreFret: baseFret,
        )
      ];
    } else {
      return [
        GuitarPosition(
          frets: [baseFret, baseFret + 2, baseFret + 2, baseFret + 1, baseFret, baseFret],
          fingers: [1, 3, 4, 2, 1, 1],
          baseFret: baseFret,
          barreFret: baseFret,
        )
      ];
    }
  }

  List<UkulelePosition> _generateFallbackUkulelePositions(String root, String quality) {
    final rootIdx = chromaticNotes.indexOf(root);
    final fret = (rootIdx + 12) % 12;
    return [
      UkulelePosition(
        frets: [(fret + 2) % 12, fret % 12, (fret + 1) % 12, (fret + 3) % 12],
        fingers: [2, 1, 3, 4],
        baseFret: 1,
      )
    ];
  }
}
