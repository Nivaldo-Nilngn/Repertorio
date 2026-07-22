import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../songs/models/song.dart';
import '../../songs/models/song_collection.dart';
import '../../songs/models/song_setlist.dart';
import '../../songs/repositories/song_repository.dart';
import '../../songs/screens/song_viewer_screen.dart';
import '../providers/editor_provider.dart';
import '../providers/manager_providers.dart';
import '../../songs/utils/chord_converter.dart';
import '../../songs/services/cifra_club_parser.dart';
import '../../songs/utils/chord_pro_parser.dart';
import '../../songs/utils/chord_transposer.dart';
import '../../songs/utils/harmonic_field_calculator.dart';
import '../../songs/utils/chord_converter_utility.dart';
import 'cifraclub_importer.dart';
import '../../midi/providers/midi_providers.dart';

enum ChordFormat { chordPro, text, traditional }

const List<String> _majorKeys = [
  'C',
  'C#',
  'D',
  'Eb',
  'E',
  'F',
  'F#',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];
const List<String> _minorKeys = [
  'Am',
  'A#m',
  'Bm',
  'Cm',
  'C#m',
  'Dm',
  'D#m',
  'Em',
  'Fm',
  'F#m',
  'Gm',
  'G#m',
];

String _extractRootFromKey(String key) {
  if (key == 'Detectar') return key;
  final match = RegExp(r'^([CDEFGAB][#b]?)').firstMatch(key);
  return match?.group(1) ?? key;
}

class ChordProTextController extends TextEditingController {
  ChordProTextController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textStr = text;
    final List<TextSpan> children = [];
    final pattern = RegExp(r'\[([^\]]+)\]|\{([^:]+):([^}]+)\}');

    // Section keywords to differentiate from chords
    final sectionKeywords = [
      'intro',
      'parte',
      'refrão',
      'pré',
      'ponte',
      'solo',
      'fim',
      'outro',
      'obs',
      'verso',
    ];

    int lastMatchEnd = 0;
    for (final match in pattern.allMatches(textStr)) {
      if (match.start > lastMatchEnd) {
        children.add(
          TextSpan(
            text: textStr.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }

      if (match.group(1) != null) {
        final content = match.group(1)!;
        final contentLower = content.toLowerCase();

        bool isSection = false;
        for (final keyword in sectionKeywords) {
          if (contentLower.contains(keyword)) {
            isSection = true;
            break;
          }
        }

        if (isSection) {
          // It's a Section Header [Intro]
          children.add(
            TextSpan(
              text: match.group(0),
              style: style?.copyWith(
                color: const Color(0xFF00FFAA), // Match the chip color
                fontWeight: FontWeight.bold,
                backgroundColor: const Color(0xFF00FFAA).withOpacity(0.1),
              ),
            ),
          );
        } else {
          // It's a chord [C]
          children.add(
            TextSpan(
              text: match.group(0),
              style: style?.copyWith(
                color: Colors.amberAccent, // Yellowish orange to pop
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
      } else if (match.group(2) != null) {
        // It's a tag {title: ...}
        children.add(
          TextSpan(
            text: match.group(0),
            style: style?.copyWith(
              color: Colors.tealAccent,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < textStr.length) {
      children.add(
        TextSpan(text: textStr.substring(lastMatchEnd), style: style),
      );
    }

    return TextSpan(style: style, children: children);
  }
}

class SongsWorkspace extends ConsumerStatefulWidget {
  const SongsWorkspace({super.key});

  @override
  ConsumerState<SongsWorkspace> createState() => _SongsWorkspaceState();
}

class _SongsWorkspaceState extends ConsumerState<SongsWorkspace> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final ChordProTextController _contentController = ChordProTextController();
  final TextEditingController _searchController = TextEditingController();

  String _currentChordPro = '';
  String _searchQuery = '';
  String _selectedKey = 'Detectar';
  String? _selectedFolderId;
  ChordFormat _format = ChordFormat.traditional;

  bool _isProcessingInternalChange = false;
  bool _isSimplified = false;
  String? _originalContent;

  void _showImportDialog(BuildContext context) {
    final TextEditingController importController = TextEditingController();
    String previewText = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colors = Theme.of(context).colorScheme;
            return AlertDialog(
              backgroundColor: colors.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Importar Cifra da Internet',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 800,
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cole abaixo a cifra no padrão tradicional (acordes ACIMA das palavras). '
                              'O sistema converte automaticamente para o formato interno.',
                              style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: paste panel
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📋  Cole a cifra aqui',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: TextField(
                                    controller: importController,
                                    maxLines: null,
                                    expands: true,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText:
                                          'G           C      G\n'
                                          'Estou preparando um caminho\n'
                                          'Em          C         G\n'
                                          '   Endireitando as veredas\n'
                                          '...',
                                      hintStyle: TextStyle(
                                        color: colors.onSurfaceVariant.withOpacity(0.4),
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: colors.surface,
                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        previewText = val.trim().isEmpty
                                            ? ''
                                            : ChordConverterUtility.convertStandardToChordPro(val);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Right: preview panel
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '✅  Resultado (ChordPro)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (previewText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Pronto!',
                                          style: TextStyle(color: Colors.greenAccent, fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: previewText.isEmpty
                                            ? colors.outline.withOpacity(0.3)
                                            : colors.primary.withOpacity(0.4),
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        previewText.isEmpty
                                            ? 'O resultado aparecerá aqui enquanto você cola...'
                                            : previewText,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: previewText.isEmpty
                                              ? colors.onSurfaceVariant.withOpacity(0.4)
                                              : colors.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: colors.onSurfaceVariant)),
                ),
                FilledButton.icon(
                  onPressed: previewText.isEmpty
                      ? null
                      : () {
                          _contentController.text = previewText;
                          _onFieldChanged();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Cifra importada e convertida com sucesso!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Aplicar Cifra'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialText = ref.read(editingChordProProvider);
      _parseChordProToFields(initialText);
      setState(() {
        _currentChordPro = initialText;
        try {
          final matchingSong = ref
              .read(songListProvider)
              .value
              ?.firstWhere((s) => s.content == initialText);
          // Only override folder if we found a matching saved song
          if (matchingSong != null) {
            _selectedFolderId = matchingSong.folderId;
          }
        } catch (_) {
          // No matching song found - keep current _selectedFolderId
        }
      });
    });

    _titleController.addListener(_onFieldChanged);
    _videoUrlController.addListener(_onFieldChanged);
    _artistController.addListener(_onFieldChanged);
    _tagsController.addListener(_onFieldChanged);
    _contentController.addListener(_onFieldChanged);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _parseChordProToFields(String chordPro) {
    _isProcessingInternalChange = true;

    final titleMatch = RegExp(r'\{title:\s*(.+?)\}').firstMatch(chordPro);
    final artistMatch = RegExp(r'\{artist:\s*(.+?)\}').firstMatch(chordPro);
    final keyMatch = RegExp(r'\{key:\s*(.+?)\}').firstMatch(chordPro);
    final videoMatch = RegExp(r'\{video:\s*(.+?)\}').firstMatch(chordPro);
    final tagsMatch = RegExp(r'\{tags:\s*(.+?)\}').firstMatch(chordPro);

    _titleController.text = titleMatch?.group(1) ?? '';
    _artistController.text = artistMatch?.group(1) ?? '';
    _videoUrlController.text = videoMatch?.group(1) ?? '';
    _tagsController.text = tagsMatch?.group(1) ?? '';

    String keyVal = keyMatch?.group(1) ?? 'Detectar';
    final allKeys = ['Detectar', ..._majorKeys, ..._minorKeys];
    if (!allKeys.contains(keyVal)) {
      keyVal = 'Detectar';
    }
    if (keyVal != 'Detectar' && _minorKeys.contains(keyVal)) {
      keyVal = _majorKeys[_minorKeys.indexOf(keyVal)];
    }
    _selectedKey = keyVal;

    // Extract content (everything that isn't a known meta tag at the top)
    String content = chordPro
        .replaceAll(RegExp(r'^\{title:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{artist:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{key:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{video:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{tags:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{tempo:.*?\}\n?', multiLine: true), '');

    // Always show traditional Brazilian cifra format (chords above lyrics)
    _contentController.text = ChordConverterUtility.convertChordProToTraditional(content.trimLeft());

    _isProcessingInternalChange = false;
  }

  void _onFieldChanged() {
    if (_isProcessingInternalChange) return;

    // Always convert from traditional format back to ChordPro for internal storage
    String contentText = ChordConverterUtility.convertStandardToChordPro(_contentController.text);

    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final video = _videoUrlController.text.trim();
    final tags = _tagsController.text.trim();
    final key = _selectedKey == 'Detectar' ? 'C' : _selectedKey;

    final builtChordPro =
        '{title: ${title.isEmpty ? "Nova Música" : title}}\n'
        '{artist: ${artist.isEmpty ? "Artista Desconhecido" : artist}}\n'
        '${video.isNotEmpty ? "{video: $video}\n" : ""}'
        '${tags.isNotEmpty ? "{tags: $tags}\n" : ""}'
        '{key: $key}\n\n'
        '$contentText';

    if (_currentChordPro != builtChordPro) {
      setState(() {
        _currentChordPro = builtChordPro;
      });
      ref.read(editingChordProProvider.notifier).state = builtChordPro;
    }
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.trim().isEmpty) return null;
    try {
      // Format: "17 Jul, 2026" or "17 Jul 2026"
      final clean = dateStr.replaceAll(',', '').trim();
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length < 3) return null;

      final months = [
        'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
        'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
      ];

      int? day, year;
      String? monthStr;

      // Try "DD MMM YYYY"
      if (int.tryParse(parts[0]) != null) {
        day = int.tryParse(parts[0]);
        monthStr = parts[1];
        year = int.tryParse(parts[2]);
      }
      // Try "MMM DD YYYY"
      else if (months.contains(parts[0])) {
        monthStr = parts[0];
        day = int.tryParse(parts[1]);
        year = int.tryParse(parts[2]);
      }

      if (day == null || monthStr == null || year == null) return null;
      final month = months.indexOf(monthStr) + 1;
      if (month == 0) return null;

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoUrlController.dispose();
    _artistController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _saveToFirebase() async {
    final title = _titleController.text.trim().isEmpty
        ? 'Unknown Title'
        : _titleController.text.trim();
    final artist = _artistController.text.trim().isEmpty
        ? 'Unknown Artist'
        : _artistController.text.trim();
    final videoUrl = _videoUrlController.text.trim();
    final tagsInput = _tagsController.text.trim();
    final key = _selectedKey == 'Detectar' ? 'C' : _selectedKey;

    final List<String> tagsList = tagsInput.isEmpty
        ? []
        : tagsInput
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();

    if (videoUrl.isNotEmpty) {
      final ytRegex = RegExp(
        r'^(https?\:\/\/)?((www\.)?youtube\.com|youtu\.?be)\/.+$',
      );
      if (!ytRegex.hasMatch(videoUrl)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Erro: URL do YouTube inválida. Verifique o link inserido.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final selectedSongId = ref.read(selectedSongIdProvider);
    final songId =
        selectedSongId ??
        title.toLowerCase().replaceAll(RegExp(r'[\s/.#\$\[\]]+'), '_');

    final song = Song(
      id: songId,
      title: title,
      artist: artist,
      key: key,
      bpm: 0,
      content: _currentChordPro,
      folderId: _selectedFolderId,
      tags: tagsList,
    );

    try {
      await ref.read(songRepositoryProvider).createSong(song);

      if (_selectedFolderId != null) {
        final allSetlists = ref.read(setlistListProvider).value ?? [];
        final matchedSetlist = allSetlists.where((s) => s.id == _selectedFolderId).firstOrNull;
        if (matchedSetlist != null) {
          final alreadyExists = matchedSetlist.items.any((item) => item.songId == song.id);
          if (!alreadyExists) {
            final newItem = SetlistItem(
              type: 'song',
              title: song.title,
              subtitle: song.artist,
              key: song.key,
              songId: song.id,
            );
            final updatedSetlist = matchedSetlist.copyWith(
              items: [...matchedSetlist.items, newItem],
            );
            await ref.read(songRepositoryProvider).updateSetlist(updatedSetlist);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Música salva no Firebase!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(selectedSongIdProvider.notifier).select(song.id);
        ref.read(isEditorVisibleProvider.notifier).state = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _insertText(String text) {
    final textSelection = _contentController.selection;
    if (textSelection.isValid) {
      final newText = _contentController.text.replaceRange(
        textSelection.start,
        textSelection.end,
        text,
      );
      _contentController.text = newText;
      _contentController.selection = TextSelection.collapsed(
        offset: textSelection.start + text.length,
      );
    } else {
      _contentController.text += text;
    }
  }

  void _transposeEditorContent({
    required String fromKey,
    required String toKey,
  }) {
    if (fromKey == 'Detectar' || toKey == 'Detectar' || fromKey == toKey)
      return;

    final notes = [
      'C',
      'C#',
      'D',
      'Eb',
      'E',
      'F',
      'F#',
      'G',
      'Ab',
      'A',
      'Bb',
      'B',
    ];
    final notesAlt = [
      'C',
      'Db',
      'D',
      'D#',
      'E',
      'F',
      'Gb',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];

    final rootFrom = _extractRootFromKey(fromKey);
    final rootTo = _extractRootFromKey(toKey);

    int indexFrom = notes.indexOf(rootFrom);
    if (indexFrom == -1) indexFrom = notesAlt.indexOf(rootFrom);

    int indexTo = notes.indexOf(rootTo);
    if (indexTo == -1) indexTo = notesAlt.indexOf(rootTo);

    if (indexFrom == -1 || indexTo == -1) return;

    int steps = indexTo - indexFrom;
    if (steps == 0) return;

    final contentText = _contentController.text;
    final regex = RegExp(r'\[(.*?)\]');
    final newContent = contentText.replaceAllMapped(regex, (match) {
      final chord = match.group(1)!;
      final transposed = ChordTransposer.transpose(chord, steps);
      return '[$transposed]';
    });

    setState(() {
      _contentController.text = newContent;
    });
  }

  
  void _simplifyChords() {
    if (_isSimplified) {
      if (_originalContent != null) {
        setState(() {
          _contentController.text = _originalContent!;
          _isSimplified = false;
        });
        _onFieldChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acordes originais restaurados.'), backgroundColor: Colors.blue),
        );
      }
    } else {
      _originalContent = _contentController.text;
      final contentText = _contentController.text;
      final regex = RegExp(r'\[(.*?)\]');
      final newContent = contentText.replaceAllMapped(regex, (match) {
        final chord = match.group(1)!;
        final lower = chord.toLowerCase();
        if (lower.contains('parte') || 
            lower.contains('refrão') || 
            lower.contains('refrao') || 
            lower.contains('intro') || 
            lower.contains('ponte') || 
            lower.contains('solo') || 
            lower.contains('final') || 
            lower.contains('interl') ||
            lower.contains('ministra')) {
          return '[$chord]';
        }
        final simplified = HarmonicFieldCalculator.extractRootChord(chord);
        return '[$simplified]';
      });
      setState(() {
        _contentController.text = newContent;
        _isSimplified = true;
      });
      _onFieldChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo Simplificado. Aviso: Desativar restaurará o texto original, perdendo edições.'), 
          duration: Duration(seconds: 4),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildToolbarButton(String label, String textToInsert) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: () => _insertText(textToInsert),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showLocalImportDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final urlController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Importar de Link',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cole a URL de um site suportado abaixo para converter magicamente!',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    style: TextStyle(color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant.withOpacity(0.5),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: colors.surface,
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'CANCELAR',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final url = urlController.text.trim();
                          if (url.isEmpty) return;

                          setDialogState(() => isLoading = true);

                          try {
                            final chordPro =
                                await CifraClubParser.fetchAndParse(url);
                            final parsed = ChordProParser.parse(chordPro);
                            final roadmapText =
                                SongRoadmapBuilder.convertToRoadmapText(parsed);

                            ref
                                .read(selectedSongIdProvider.notifier)
                                .select(null);
                            ref.read(editingChordProProvider.notifier).state =
                                roadmapText;
                            ref.read(isEditorVisibleProvider.notifier).state =
                                true;

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Importado com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('IMPORTAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    final songsCount = ref.watch(songListProvider).value?.length ?? 0;
    final favoritesCount =
        ref.watch(songListProvider).value?.where((s) => s.isFavorite).length ??
        0;
    final setlistsCount = ref.watch(setlistListProvider).value?.length ?? 0;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primary.withOpacity(0.1),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.dashboard_rounded,
                  size: 64,
                  color: colors.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Bem-vindo ao KordApp',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seu songbook digital definitivo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colors.onSurfaceVariant.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildStatCard(
                    'Músicas Salvas',
                    songsCount.toString(),
                    Icons.library_music,
                    colors,
                  ),
                  _buildStatCard(
                    'Favoritas',
                    favoritesCount.toString(),
                    Icons.favorite,
                    colors,
                  ),
                  _buildStatCard(
                    'Repertórios',
                    setlistsCount.toString(),
                    Icons.queue_music,
                    colors,
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showLocalImportDialog(context),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Importar Mágica'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      backgroundColor: colors.primary.withOpacity(0.08),
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary.withOpacity(0.2)),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(selectedSongIdProvider.notifier).select(null);
                      ref
                          .read(editingChordProProvider.notifier)
                          .state = '''{title: Nova Música}
{artist: Artista}
{key: C}
{tempo: 70}

{c: Verse 1}
Coloque sua [C]letra aqui
E os acordes [G]entre colchetes
''';
                      ref.read(isEditorVisibleProvider.notifier).state = true;
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Criar Manualmente'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    ColorScheme colors,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.primary, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(editingChordProProvider, (previous, next) {
      if (_currentChordPro != next && !_isProcessingInternalChange) {
        _parseChordProToFields(next);
        setState(() {
          _currentChordPro = next;
          try {
            final matchingSong = ref
                .read(songListProvider)
                .value
                ?.firstWhere((s) => s.content == next);
            // Only override folder if we found a matching saved song
            if (matchingSong != null) {
              _selectedFolderId = matchingSong.folderId;
            }
          } catch (_) {
            // No matching song found - keep current _selectedFolderId
          }
        });
      }
    });

    final colors = Theme.of(context).colorScheme;

    final savedSongs = ref.watch(songListProvider).value ?? [];
    final allSetlists = ref.watch(setlistListProvider).value ?? [];

    // Ordena os repertórios colocando os mais recentes (criados por último) no topo
    final sortedSetlists = List<SongSetlist>.from(
      allSetlists,
    ).reversed.toList();
    // Limita a exibição rápida no dropdown para os 10 mais recentes para não poluir a tela
    final setlists = sortedSetlists.take(10).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Only show setlists with no date or with today/future dates
    final futureSetlists = allSetlists.where((sl) {
      if (sl.date.trim().isEmpty) return false; // exclude undated setlists from song editor
      final parsedDate = _parseDate(sl.date);
      if (parsedDate == null) return false; // can't parse = exclude
      return !parsedDate.isBefore(today); // only today or future
    }).toList()
      ..sort((a, b) {
        final da = _parseDate(a.date);
        final db = _parseDate(b.date);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db); // nearest date first
      });

    final filter = ref.watch(songFilterProvider);
    final activeTab = ref.watch(sidebarTabProvider);

    final filteredSongs = savedSongs.where((song) {
      if (_searchQuery.isNotEmpty) {
        final matchesTitle = song.title.toLowerCase().contains(_searchQuery);
        final matchesArtist = song.artist.toLowerCase().contains(_searchQuery);
        return matchesTitle || matchesArtist;
      }

      if (activeTab == SidebarTab.favorites || filter.onlyFavorites) {
        if (!song.isFavorite) return false;
      }
      if (filter.folderId != null) {
        final matchingSetlist = setlists
            .where((s) => s.id == filter.folderId)
            .firstOrNull;
        if (matchingSetlist != null) {
          final containsSong = matchingSetlist.items.any(
            (item) =>
                item.type == 'song' &&
                (item.songId == song.id ||
                    item.title.trim().toLowerCase() ==
                        song.title.trim().toLowerCase()),
          );
          if (!containsSong) return false;
        } else {
          return false;
        }
      }
      if (filter.artist != null) {
        if (song.artist.trim().toLowerCase() !=
            filter.artist!.trim().toLowerCase())
          return false;
      }
      if (filter.tag != null) {
        if (!song.tags.any(
          (t) => t.trim().toLowerCase() == filter.tag!.trim().toLowerCase(),
        ))
          return false;
      }
      return true;
    }).toList();

    if (filter.folderId != null && _searchQuery.isEmpty) {
      final matchingSetlist = setlists
          .where((s) => s.id == filter.folderId)
          .firstOrNull;
      if (matchingSetlist != null) {
        filteredSongs.sort((a, b) {
          final indexA = matchingSetlist.items.indexWhere(
            (item) =>
                item.type == 'song' &&
                (item.songId == a.id ||
                    item.title.trim().toLowerCase() ==
                        a.title.trim().toLowerCase()),
          );
          final indexB = matchingSetlist.items.indexWhere(
            (item) =>
                item.type == 'song' &&
                (item.songId == b.id ||
                    item.title.trim().toLowerCase() ==
                        b.title.trim().toLowerCase()),
          );

          // Se não encontrar (por algum motivo improvável), mantém a ordem
          if (indexA == -1 || indexB == -1) return 0;
          return indexA.compareTo(indexB);
        });
      }
    }

    ref.listen<String?>(midiActionStreamProvider, (previous, next) {
      if (next == 'next_song' || next == 'prev_song') {
        if (filteredSongs.isEmpty) return;
        
        final currentId = ref.read(selectedSongIdProvider);
        int currentIndex = filteredSongs.indexWhere((s) => s.id == currentId);
        if (currentIndex == -1) currentIndex = 0;
        
        int newIndex = currentIndex;
        if (next == 'next_song') {
          newIndex = (currentIndex + 1) % filteredSongs.length;
        } else if (next == 'prev_song') {
          newIndex = (currentIndex - 1) % filteredSongs.length;
          if (newIndex < 0) newIndex += filteredSongs.length;
        }
        
        final nextSong = filteredSongs[newIndex];
        ref.read(selectedSongIdProvider.notifier).select(nextSong.id);
        ref.read(editingChordProProvider.notifier).state = nextSong.content;
      }
    });

    final selectedSongId = ref.watch(selectedSongIdProvider);
    final isEditorVisible = ref.watch(isEditorVisibleProvider);

    final bool isSelectedSongInList = filteredSongs.any(
      (s) => s.id == selectedSongId,
    );

    if (!isSelectedSongInList && !isEditorVisible && filteredSongs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(selectedSongIdProvider.notifier)
            .select(filteredSongs.first.id);
        ref.read(editingChordProProvider.notifier).state =
            filteredSongs.first.content;
      });
    }

    final showPreview =
        isEditorVisible || (selectedSongId != null && isSelectedSongInList);

    Song? currentSavedSong;
    if (selectedSongId != null) {
      try {
        currentSavedSong = savedSongs.firstWhere((s) => s.id == selectedSongId);
      } catch (_) {}
    }

    final isSaved =
        currentSavedSong != null &&
        currentSavedSong.content == _currentChordPro;

    // Compute filter text label
    String titleLabel = activeTab == SidebarTab.favorites
        ? 'Favoritos'
        : 'Músicas';
    String? filterLabel;
    if (filter.folderId != null) {
      final matched = setlists
          .where((s) => s.id == filter.folderId)
          .firstOrNull;
      filterLabel = matched?.name ?? 'Repertório';
    } else if (filter.artist != null) {
      titleLabel = filter.artist!;
      filterLabel = 'Artista';
    }

    final Set<String> uniqueTags = {};
    for (final song in savedSongs) {
      for (final t in song.tags) {
        if (t.trim().isNotEmpty) {
          uniqueTags.add(t.trim());
        }
      }
    }
    final sortedTags = uniqueTags.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return _buildMobileLayout(
            context,
            colors,
            filteredSongs,
            setlists,
            selectedSongId,
            isEditorVisible,
            showPreview,
            currentSavedSong,
            isSaved,
            titleLabel,
            filterLabel,
            sortedTags,
            filter,
          );
        }
        return _buildDesktopLayout(
          colors,
          filteredSongs,
          setlists,
          futureSetlists,
          selectedSongId,
          isEditorVisible,
          showPreview,
          currentSavedSong,
          isSaved,
          titleLabel,
          filterLabel,
          activeTab,
          filter,
          sortedTags,
        );
      },
    );
  }

  // ─── MOBILE LAYOUT ───────────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    ColorScheme colors,
    List<Song> filteredSongs,
    List<SongSetlist> setlists,
    String? selectedSongId,
    bool isEditorVisible,
    bool showPreview,
    Song? currentSavedSong,
    bool isSaved,
    String titleLabel,
    String? filterLabel,
    List<String> sortedTags,
    SongFilter filter,
  ) {
    // If editor is open on mobile, show full-screen editor
    if (isEditorVisible) {
      return _buildMobileEditor(
        context,
        colors,
        currentSavedSong,
        isSaved,
        setlists,
      );
    }

    // Otherwise show full-screen list
    return _buildMobileSongList(
      context,
      colors,
      filteredSongs,
      setlists,
      selectedSongId,
      currentSavedSong,
      titleLabel,
      filterLabel,
      sortedTags,
      filter,
    );
  }

  Widget _buildMobileSongList(
    BuildContext context,
    ColorScheme colors,
    List<Song> filteredSongs,
    List<SongSetlist> setlists,
    String? selectedSongId,
    Song? currentSavedSong,
    String titleLabel,
    String? filterLabel,
    List<String> sortedTags,
    SongFilter filter,
  ) {
    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: colors.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      titleLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (filterLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              filterLabel,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () =>
                                  ref.read(songFilterProvider.notifier).clear(),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.outline.withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar música...',
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.outline.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: ref.watch(songFilterProvider).folderId,
                      isExpanded: true,
                      dropdownColor: colors.surfaceContainer,
                      style: TextStyle(color: colors.onSurface, fontSize: 12),
                      hint: Text(
                        'Todos os Repertórios',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos os Repertórios'),
                        ),
                        ...setlists.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (newFolderId) {
                        ref
                            .read(songFilterProvider.notifier)
                            .setFolder(newFolderId);
                      },
                    ),
                  ),
                ),
                if (sortedTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: sortedTags.map((tag) {
                        final isSelected =
                            ref.watch(songFilterProvider).tag == tag;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (selected) {
                              ref
                                  .read(songFilterProvider.notifier)
                                  .setTag(selected ? tag : null);
                            },
                            selectedColor: colors.primary.withOpacity(0.2),
                            checkmarkColor: colors.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            backgroundColor: colors.surfaceContainerHighest
                                .withOpacity(0.5),
                            side: BorderSide(
                              color: isSelected
                                  ? colors.primary.withOpacity(0.5)
                                  : Colors.transparent,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Songs list
          Expanded(
            child: ref
                .watch(songListProvider)
                .when(
                  data: (_) {
                    if (filteredSongs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.music_note_rounded,
                                size: 64,
                                color: colors.primary.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhuma música encontrada.',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () {
                                  final filterArtist = ref
                                      .read(songFilterProvider)
                                      .artist;
                                  final initialArtist =
                                      filterArtist ?? 'Artista';
                                  ref
                                          .read(
                                            editingChordProProvider.notifier,
                                          )
                                          .state =
                                      '''{title: Nova Música}
{artist: $initialArtist}
{key: C}
{tempo: 70}

{c: Verse 1}
Coloque sua [C]letra aqui
E os acordes [G]entre colchetes
''';
                                  ref
                                      .read(selectedSongIdProvider.notifier)
                                      .select(null);
                                  ref
                                          .read(
                                            isEditorVisibleProvider.notifier,
                                          )
                                          .state =
                                      true;
                                },
                                child: const Text('Criar Nova Música'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final isActive = selectedSongId == song.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () {
                              ref
                                  .read(selectedSongIdProvider.notifier)
                                  .select(song.id);
                              ref.read(editingChordProProvider.notifier).state =
                                  song.content;
                              // On mobile: push song viewer screen
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => _MobileSongViewerPage(
                                    song: song,
                                    chordProText: song.content,
                                    onFavoriteToggle: () {
                                      final updated = song.copyWith(
                                        isFavorite: !song.isFavorite,
                                      );
                                      ref
                                          .read(songRepositoryProvider)
                                          .updateSong(updated);
                                    },
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colors.primary.withOpacity(0.12)
                                    : colors.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                  left: BorderSide(
                                    color: isActive
                                        ? colors.primary
                                        : Colors.transparent,
                                    width: 3.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: TextStyle(
                                            fontWeight: isActive
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isActive
                                                ? colors.primary
                                                : colors.onSurface,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          song.artist,
                                          style: TextStyle(
                                            color: isActive
                                                ? colors.primary.withOpacity(
                                                    0.8,
                                                  )
                                                : colors.onSurfaceVariant
                                                      .withOpacity(0.7),
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (song.isFavorite)
                                    Icon(
                                      Icons.favorite,
                                      size: 16,
                                      color: colors.primary.withOpacity(0.7),
                                    ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      song.key,
                                      style: TextStyle(
                                        color: colors.onSecondaryContainer,
                                        fontSize: 11,
                                        fontFamily: 'Consolas',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: colors.onSurfaceVariant.withOpacity(
                                      0.5,
                                    ),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Erro: $e')),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileEditor(
    BuildContext context,
    ColorScheme colors,
    Song? currentSavedSong,
    bool isSaved,
    List<SongSetlist> setlists,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureSetlists = setlists.where((sl) {
      if (sl.date.trim().isEmpty) return false;
      final parsedDate = _parseDate(sl.date);
      if (parsedDate == null) return false;
      return !parsedDate.isBefore(today);
    }).toList()
      ..sort((a, b) {
        final da = _parseDate(a.date);
        final db = _parseDate(b.date);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    return Container(
      color: colors.surfaceContainer,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: colors.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      tooltip: 'Voltar para a Lista',
                      onPressed: () {
                        ref.read(isEditorVisibleProvider.notifier).state =
                            false;
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'EDITOR DE MÚSICA',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _showImportDialog(context),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('IMPORTAR'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _saveToFirebase,
                      icon: const Icon(Icons.cloud_upload, size: 16),
                      label: const Text('SALVAR'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Título da música',
                      labelStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _artistController,
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Artista / Cantor',
                      labelStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _videoUrlController,
                    style: TextStyle(fontSize: 13, color: colors.onSurface),
                    decoration: InputDecoration(
                      labelText: 'URL do Vídeo (YouTube)',
                      labelStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tagsController,
                    style: TextStyle(fontSize: 13, color: colors.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Tags / Gêneros (separados por vírgula)',
                      labelStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  // Repertório / Coleção
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Repertório / Coleção',
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: currentSavedSong?.folderId ?? _selectedFolderId,
                        isExpanded: true,
                        dropdownColor: colors.surfaceContainerHigh,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Nenhum Repertório'),
                          ),
                          ...futureSetlists.map(
                            (col) => DropdownMenuItem<String?>(
                              value: col.id,
                              child: Text(
                                col.date.isNotEmpty ? '${col.name} - ${col.date}' : col.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) async {
                          setState(() => _selectedFolderId = v);
                          if (currentSavedSong != null) {
                            final updated = currentSavedSong.copyWith(
                              folderId: v,
                            );
                            await ref
                                .read(songRepositoryProvider)
                                .updateSong(updated);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tom Original',
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedKey,
                        isExpanded: true,
                        dropdownColor: colors.surfaceContainerHigh,
                        style: TextStyle(color: colors.onSurface, fontSize: 13),
                        selectedItemBuilder: (context) {
                          return ['Detectar', ..._majorKeys].map((k) {
                            if (k == 'Detectar') {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Detectar',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }
                            final idx = _majorKeys.indexOf(k);
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$k / ${_minorKeys[idx]}',
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        items: ['Detectar', ..._majorKeys].map((k) {
                          if (k == 'Detectar') {
                            return DropdownMenuItem(
                              value: 'Detectar',
                              child: Text(
                                'Detectar',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          final idx = _majorKeys.indexOf(k);
                          return DropdownMenuItem(
                            value: k,
                            child: Text('$k / ${_minorKeys[idx]}'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            _transposeEditorContent(
                              fromKey: _selectedKey,
                              toKey: v,
                            );
                            setState(() => _selectedKey = v);
                            _onFieldChanged();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Simplificar Acordes',
                  child: IconButton.filledTonal(
                    onPressed: _simplifyChords,
                    icon: Icon(_isSimplified ? Icons.auto_fix_off : Icons.auto_fix_high, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: _isSimplified ? colors.primaryContainer : colors.surfaceContainerHighest,
                        foregroundColor: _isSimplified ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                      ),
                  ),
                ),
              ],
            ),
                  const SizedBox(height: 16),
                  // Toolbar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildToolbarButton('Introdução', '[Introdução]\n'),
                        const SizedBox(width: 6),
                        _buildToolbarButton(
                          'Primeira Parte',
                          '[Primeira Parte]\n',
                        ),
                        const SizedBox(width: 6),
                        _buildToolbarButton('Pré-refrão', '[Pré-refrão]\n'),
                        const SizedBox(width: 6),
                        _buildToolbarButton('Refrão', '[Refrão]\n'),
                        const SizedBox(width: 6),
                        _buildToolbarButton(
                          'Segunda Parte',
                          '[Segunda Parte]\n',
                        ),
                        const SizedBox(width: 6),
                        _buildToolbarButton('Ponte', '[Ponte]\n'),
                        const SizedBox(width: 6),
                        _buildToolbarButton('OBS', 'OBS: '),

                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Content field (fixed height)
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colors.outline.withOpacity(0.2),
                      ),
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                        color: colors.onSurface,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Cole a letra e os acordes aqui...',
                        hintStyle: TextStyle(
                          color: colors.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── DESKTOP LAYOUT ──────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(
    ColorScheme colors,
    List<Song> filteredSongs,
    List<SongSetlist> setlists,
    List<SongSetlist> futureSetlists,
    String? selectedSongId,
    bool isEditorVisible,
    bool showPreview,
    Song? currentSavedSong,
    bool isSaved,
    String titleLabel,
    String? filterLabel,
    SidebarTab activeTab,
    SongFilter filter,
    List<String> sortedTags,
  ) {
    return Row(
      children: [
        // Left Column: Songs List
        if (!isEditorVisible)
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              border: Border(
                right: BorderSide(color: colors.outline.withOpacity(0.2)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (filter.artist != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Voltar para Artistas',
                                onPressed: () {
                                  ref.read(songFilterProvider.notifier).clear();
                                  ref
                                      .read(sidebarTabProvider.notifier)
                                      .setTab(SidebarTab.artists);
                                },
                              ),
                            ),
                          Expanded(
                            child: Text(
                              titleLabel,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (filterLabel != null)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    filterLabel,
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      ref
                                          .read(songFilterProvider.notifier)
                                          .clear();
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (activeTab == SidebarTab.songs) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colors.outline.withOpacity(0.3),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Pesquisar música...',
                              hintStyle: TextStyle(
                                color: colors.onSurfaceVariant.withOpacity(0.7),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.search,
                                size: 16,
                                color: colors.onSurfaceVariant,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        if (filter.artist == null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainer,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: colors.outline.withOpacity(0.3),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: filter.folderId,
                                isExpanded: true,
                                dropdownColor: colors.surfaceContainer,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 12,
                                ),
                                hint: Text(
                                  'Filtrar por Repertório',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Todos os Repertórios'),
                                  ),
                                  ...setlists.map(
                                    (s) => DropdownMenuItem<String?>(
                                      value: s.id,
                                      child: Text(s.name),
                                    ),
                                  ),
                                ],
                                onChanged: (newFolderId) {
                                  ref
                                      .read(songFilterProvider.notifier)
                                      .setFolder(newFolderId);
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (sortedTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: sortedTags.map((tag) {
                              final isSelected = filter.tag == tag;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(tag),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    ref
                                        .read(songFilterProvider.notifier)
                                        .setTag(selected ? tag : null);
                                  },
                                  selectedColor: colors.primary.withOpacity(
                                    0.2,
                                  ),
                                  checkmarkColor: colors.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  backgroundColor: colors
                                      .surfaceContainerHighest
                                      .withOpacity(0.5),
                                  side: BorderSide(
                                    color: isSelected
                                        ? colors.primary.withOpacity(0.5)
                                        : Colors.transparent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ref
                      .watch(songListProvider)
                      .when(
                        data: (_) {
                          if (filteredSongs.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Nenhuma música encontrada.',
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: () {
                                        final filterArtist = ref
                                            .read(songFilterProvider)
                                            .artist;
                                        final initialArtist =
                                            filterArtist ?? 'Artista';
                                        ref
                                                .read(
                                                  editingChordProProvider
                                                      .notifier,
                                                )
                                                .state =
                                            '''{title: Nova Música}
{artist: $initialArtist}
{key: C}
{tempo: 70}

{c: Verse 1}
Coloque sua [C]letra aqui
E os acordes [G]entre colchetes
''';
                                        ref
                                            .read(
                                              selectedSongIdProvider.notifier,
                                            )
                                            .select(null);
                                        ref
                                                .read(
                                                  isEditorVisibleProvider
                                                      .notifier,
                                                )
                                                .state =
                                            true;
                                      },
                                      child: const Text('Criar Nova Música'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            itemCount: filteredSongs.length,
                            itemBuilder: (context, index) {
                              final song = filteredSongs[index];
                              final isActive = selectedSongId == song.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () {
                                    ref
                                        .read(selectedSongIdProvider.notifier)
                                        .select(song.id);
                                    ref
                                        .read(editingChordProProvider.notifier)
                                        .state = song
                                        .content;
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? colors.primary.withOpacity(0.12)
                                          : colors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isActive
                                          ? Border.all(
                                              color: colors.primary.withOpacity(
                                                0.5,
                                              ),
                                            )
                                          : Border.all(
                                              color: colors.outline.withOpacity(
                                                0.2,
                                              ),
                                            ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? colors.primary.withOpacity(
                                                    0.2,
                                                  )
                                                : colors
                                                      .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            song.isFavorite
                                                ? Icons.favorite
                                                : Icons.music_note,
                                            color: isActive
                                                ? colors.primary
                                                : colors.onSurfaceVariant,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                song.title,
                                                style: TextStyle(
                                                  fontWeight: isActive
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: isActive
                                                      ? colors.primary
                                                      : colors.onSurface,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                song.artist,
                                                style: TextStyle(
                                                  color: isActive
                                                      ? colors.primary
                                                            .withOpacity(0.8)
                                                      : colors.onSurfaceVariant
                                                            .withOpacity(0.8),
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Center(child: Text('Erro: $e')),
                      ),
                ),
              ],
            ),
          ),

        // Center Column: Editor
        if (isEditorVisible)
          Expanded(
            flex: 1,
            child: Container(
              color: colors.surfaceContainer,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    color: colors.surfaceContainer,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, size: 20),
                              tooltip: 'Voltar para a Lista',
                              onPressed: () {
                                ref
                                        .read(isEditorVisibleProvider.notifier)
                                        .state =
                                    false;
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'EDITOR DE MÚSICA',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showImportDialog(context),
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('IMPORTAR CIFRA'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.amberAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _saveToFirebase,
                              icon: const Icon(Icons.cloud_upload, size: 16),
                              label: const Text('SALVAR MÚSICA'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Title & Artist
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _titleController,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Título da música',
                                    labelStyle: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _artistController,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Artista / Cantor',
                                    labelStyle: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Row 2: Video URL, Collection dropdown, and Original Key dropdown
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _videoUrlController,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'URL do Vídeo (YouTube)',
                                    labelStyle: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Repertório / Coleção',
                                    labelStyle: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value:
                                          currentSavedSong?.folderId ??
                                          _selectedFolderId,
                                      isExpanded: true,
                                      dropdownColor:
                                          colors.surfaceContainerHigh,
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: 14,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('Nenhum Repertório'),
                                        ),
                                        ...futureSetlists.map(
                                          (col) => DropdownMenuItem<String?>(
                                            value: col.id,
                                            child: Text(
                                              col.date.isNotEmpty ? '${col.name} - ${col.date}' : col.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) async {
                                        setState(() => _selectedFolderId = v);
                                        if (currentSavedSong != null) {
                                          final updated = currentSavedSong
                                              .copyWith(folderId: v);
                                          await ref
                                              .read(songRepositoryProvider)
                                              .updateSong(updated);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Repertório atualizado!',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Tom Original',
                                    labelStyle: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedKey,
                                      isExpanded: true,
                                      dropdownColor:
                                          colors.surfaceContainerHigh,
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: 14,
                                      ),
                                      selectedItemBuilder: (context) {
                                        return ['Detectar', ..._majorKeys].map((
                                          k,
                                        ) {
                                          if (k == 'Detectar') {
                                            return Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Detectar',
                                                style: TextStyle(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            );
                                          }
                                          final idx = _majorKeys.indexOf(k);
                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '$k / ${_minorKeys[idx]}',
                                              style: TextStyle(
                                                color: colors.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                          );
                                        }).toList();
                                      },
                                      items: ['Detectar', ..._majorKeys].map((
                                        k,
                                      ) {
                                        if (k == 'Detectar') {
                                          return DropdownMenuItem(
                                            value: 'Detectar',
                                            child: Text(
                                              'Detectar',
                                              style: TextStyle(
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          );
                                        }
                                        final idx = _majorKeys.indexOf(k);
                                        return DropdownMenuItem(
                                          value: k,
                                          child: Text(
                                            '$k / ${_minorKeys[idx]}',
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          _transposeEditorContent(
                                            fromKey: _selectedKey,
                                            toKey: v,
                                          );
                                          setState(() => _selectedKey = v);
                                          _onFieldChanged();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                height: 56,
                                child: FilledButton.icon(
                                  onPressed: _simplifyChords,
                                icon: Icon(_isSimplified ? Icons.auto_fix_off : Icons.auto_fix_high, size: 20),
                                label: const Text('Simplificar'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _isSimplified ? colors.primaryContainer : colors.surfaceContainerHighest,
                                  foregroundColor: _isSimplified ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  elevation: 0,
                                ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Toolbar
                          Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildToolbarButton(
                                        'Introdução',
                                        '[Introdução]\n',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildToolbarButton(
                                        'Primeira Parte',
                                        '[Primeira Parte]\n',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildToolbarButton(
                                        'Pré-refrão',
                                        '[Pré-refrão]\n',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildToolbarButton(
                                        'Refrão',
                                        '[Refrão]\n',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildToolbarButton(
                                        'Segunda Parte',
                                        '[Segunda Parte]\n',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildToolbarButton('Ponte', '[Ponte]\n'),
                                      const SizedBox(width: 8),
                                      _buildToolbarButton('OBS', 'OBS: '),

                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Main content
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: colors.outline.withOpacity(0.2),
                                ),
                                color: colors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: TextField(
                                controller: _contentController,
                                maxLines: null,
                                expands: true,
                                style: TextStyle(
                                  fontFamily: 'Consolas',
                                  fontSize: 14,
                                  color: colors.onSurface,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Cole a letra e os acordes aqui...',
                                  hintStyle: TextStyle(
                                    color: colors.onSurfaceVariant.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Divider
        if (isEditorVisible) Container(width: 1, color: colors.outline),

        // Right Column: Preview
        Expanded(
          flex: isEditorVisible ? 1 : 3,
          child: Container(
            color: colors.surface,
            child: showPreview
                ? SongViewerScreen(
                    song: currentSavedSong,
                    chordProText: _currentChordPro,
                    hideAppBar: true,
                    isPreviewMode: isEditorVisible,
                    isFavorite: currentSavedSong?.isFavorite ?? false,
                    onFavoriteToggle: () {
                      if (currentSavedSong != null) {
                        final updated = currentSavedSong.copyWith(
                          isFavorite: !currentSavedSong.isFavorite,
                        );
                        ref.read(songRepositoryProvider).updateSong(updated);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              updated.isFavorite
                                  ? 'Adicionado aos Favoritos!'
                                  : 'Removido dos Favoritos.',
                            ),
                            backgroundColor: updated.isFavorite
                                ? Colors.green
                                : Colors.grey,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Salve a música no banco de dados primeiro!',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                  )
                : _buildEmptyState(colors),
          ),
        ),
      ],
    );
  }
}

// ─── Mobile Song Viewer Page ─────────────────────────────────────────────────

class _MobileSongViewerPage extends ConsumerWidget {
  final Song song;
  final String chordProText;
  final VoidCallback onFavoriteToggle;

  const _MobileSongViewerPage({
    required this.song,
    required this.chordProText,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SongViewerScreen(
      song: song,
      chordProText: chordProText,
      hideAppBar: false,
      isPreviewMode: false,
      isFavorite: song.isFavorite,
      onFavoriteToggle: onFavoriteToggle,
    );
  }
}
