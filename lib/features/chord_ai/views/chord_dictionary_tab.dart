import 'package:flutter/material.dart';
import '../services/chord_repository.dart';
import '../models/chord_data.dart';
import '../widgets/guitar_fretboard.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/ukulele_fretboard.dart';

class ChordDictionaryTab extends StatefulWidget {
  final ChordRepository chordRepository;

  const ChordDictionaryTab({
    super.key,
    required this.chordRepository,
  });

  @override
  State<ChordDictionaryTab> createState() => _ChordDictionaryTabState();
}

class _ChordDictionaryTabState extends State<ChordDictionaryTab> {
  String _selectedRoot = 'C';
  String _selectedQuality = 'maj';
  int _variationIndex = 0;
  InstrumentType _selectedInstrument = InstrumentType.guitar;
  final TextEditingController _searchController = TextEditingController();
  List<ChordInfo> _searchResults = [];

  final List<String> roots = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  final List<(String, String)> qualities = [
    ('maj', 'Maior'),
    ('m', 'Menor (m)'),
    ('7', '7ª Dominante'),
    ('m7', 'Menor com 7ª'),
    ('maj7', '7ª Maior (7M)'),
    ('sus4', 'Suspenso 4'),
    ('sus2', 'Suspenso 2'),
    ('dim', 'Diminuto'),
    ('aug', 'Aumentado'),
  ];

  @override
  void initState() {
    super.initState();
    _updateSearch();
  }

  void _updateSearch() {
    if (_searchController.text.trim().isNotEmpty) {
      _searchResults = widget.chordRepository.search(_searchController.text);
    } else {
      _searchResults = [];
    }
    setState(() {});
  }

  String get _currentChordName => '$_selectedRoot${_selectedQuality == 'maj' ? '' : _selectedQuality}';

  @override
  Widget build(BuildContext context) {
    final chordInfo = widget.chordRepository.getChord(_currentChordName);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de Busca
          TextField(
            controller: _searchController,
            onChanged: (val) => _updateSearch(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar acorde (ex: Dm7, F#, Cadd9, G7)...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
              filled: true,
              fillColor: const Color(0xFF141722),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00E5FF)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Seletor de Tônica (Root Note)
          const Text(
            'TÔNICA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: roots.map((root) {
                final isSelected = _selectedRoot == root;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(root),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedRoot = root;
                        _variationIndex = 0;
                      });
                    },
                    selectedColor: const Color(0xFF00E5FF),
                    backgroundColor: const Color(0xFF141722),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.08),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Seletor de Qualidade do Acorde
          const Text(
            'QUALIDADE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: qualities.map((q) {
                final isSelected = _selectedQuality == q.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(q.$2),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedQuality = q.$1;
                        _variationIndex = 0;
                      });
                    },
                    selectedColor: const Color(0xFFE040FB),
                    backgroundColor: const Color(0xFF141722),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.08),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Cartão do Acorde Selecionado com Notas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1F30), Color(0xFF141722)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentChordName,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Notas: ${chordInfo.notes.join(" - ")}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Botão de Variações de Posição
                if (chordInfo.guitarPositions.length > 1)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _variationIndex = (_variationIndex + 1) % chordInfo.guitarPositions.length;
                      });
                    },
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: Text('Variação ${_variationIndex + 1}/${chordInfo.guitarPositions.length}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3246),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seletor de Instrumento
          _buildInstrumentTabs(),
          const SizedBox(height: 16),

          // Diagrama do Instrumento
          Center(child: _buildInstrumentDiagram(chordInfo)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInstrumentTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTabOption(InstrumentType.guitar, 'Violão', Icons.music_note),
          _buildTabOption(InstrumentType.piano, 'Piano', Icons.piano),
          _buildTabOption(InstrumentType.ukulele, 'Ukulele', Icons.straighten),
        ],
      ),
    );
  }

  Widget _buildTabOption(InstrumentType type, String title, IconData icon) {
    final isSelected = _selectedInstrument == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedInstrument = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C3246) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? const Color(0xFF00E5FF) : Colors.white54),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstrumentDiagram(ChordInfo chordInfo) {
    switch (_selectedInstrument) {
      case InstrumentType.guitar:
        final pos = chordInfo.guitarPositions.isNotEmpty
            ? chordInfo.guitarPositions[_variationIndex % chordInfo.guitarPositions.length]
            : const GuitarPosition(frets: [-1, 3, 2, 0, 1, 0]);
        return GuitarFretboardWidget(position: pos);

      case InstrumentType.piano:
        return PianoKeyboardWidget(activeNotes: chordInfo.notes);

      case InstrumentType.ukulele:
        final pos = chordInfo.ukulelePositions.isNotEmpty
            ? chordInfo.ukulelePositions.first
            : const UkulelePosition(frets: [0, 0, 0, 3]);
        return UkuleleFretboardWidget(position: pos);
    }
  }
}
