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

enum ChordFormat { chordPro, text }

class EditWorkspace extends ConsumerStatefulWidget {
  const EditWorkspace({super.key});

  @override
  ConsumerState<EditWorkspace> createState() => _EditWorkspaceState();
}

class _EditWorkspaceState extends ConsumerState<EditWorkspace> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  String _currentChordPro = '';
  String _selectedKey = 'Detectar';
  String? _selectedFolderId;
  ChordFormat _format = ChordFormat.chordPro;
  
  bool _isProcessingInternalChange = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialText = ref.read(editingChordProProvider);
      _parseChordProToFields(initialText);
      setState(() {
        _currentChordPro = initialText;
        try {
          final matchingSong = ref.read(songListProvider).value?.firstWhere((s) => s.content == initialText);
          _selectedFolderId = matchingSong?.folderId;
        } catch (_) {
          _selectedFolderId = null;
        }
      });
    });

    _titleController.addListener(_onFieldChanged);
    _videoUrlController.addListener(_onFieldChanged);
    _artistController.addListener(_onFieldChanged);
    _contentController.addListener(_onFieldChanged);
  }

  void _parseChordProToFields(String chordPro) {
    _isProcessingInternalChange = true;
    
    final titleMatch = RegExp(r'\{title:\s*(.+?)\}').firstMatch(chordPro);
    final artistMatch = RegExp(r'\{artist:\s*(.+?)\}').firstMatch(chordPro);
    final keyMatch = RegExp(r'\{key:\s*(.+?)\}').firstMatch(chordPro);
    final videoMatch = RegExp(r'\{video:\s*(.+?)\}').firstMatch(chordPro);
    
    _titleController.text = titleMatch?.group(1) ?? '';
    _artistController.text = artistMatch?.group(1) ?? '';
    _videoUrlController.text = videoMatch?.group(1) ?? '';
    
    String keyVal = keyMatch?.group(1) ?? 'Detectar';
    if (!['Detectar', 'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'].contains(keyVal)) {
      keyVal = 'Detectar';
    }
    _selectedKey = keyVal;
    
    // Extract content (everything that isn't a known meta tag at the top)
    String content = chordPro
        .replaceAll(RegExp(r'^\{title:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{artist:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{key:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{video:.*?\}\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^\{tempo:.*?\}\n?', multiLine: true), '');
        
    if (_format == ChordFormat.text) {
      _contentController.text = ChordConverter.chordProToText(content);
    } else {
      _contentController.text = content.trimLeft();
    }
    
    _isProcessingInternalChange = false;
  }

  void _onFieldChanged() {
    if (_isProcessingInternalChange) return;
    
    String contentText = _contentController.text;
    if (_format == ChordFormat.text) {
      contentText = ChordConverter.textToChordPro(contentText);
    }
    
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    final video = _videoUrlController.text.trim();
    final key = _selectedKey == 'Detectar' ? 'C' : _selectedKey;
    
    final builtChordPro = '{title: ${title.isEmpty ? "Nova Música" : title}}\n'
                          '{artist: ${artist.isEmpty ? "Artista Desconhecido" : artist}}\n'
                          '${video.isNotEmpty ? "{video: $video}\n" : ""}'
                          '{key: $key}\n\n'
                          '$contentText';
                          
    if (_currentChordPro != builtChordPro) {
      setState(() {
        _currentChordPro = builtChordPro;
      });
      ref.read(editingChordProProvider.notifier).state = builtChordPro;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoUrlController.dispose();
    _artistController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveToFirebase() async {
    final title = _titleController.text.trim().isEmpty ? 'Unknown Title' : _titleController.text.trim();
    final artist = _artistController.text.trim().isEmpty ? 'Unknown Artist' : _artistController.text.trim();
    final key = _selectedKey == 'Detectar' ? 'C' : _selectedKey;
    
    final songId = title.toLowerCase().replaceAll(RegExp(r'[\s/.#\$\[\]]+'), '_');

    final song = Song(
      id: songId,
      title: title,
      artist: artist,
      key: key,
      bpm: 0,
      content: _currentChordPro,
      folderId: _selectedFolderId,
    );

    try {
      await ref.read(songRepositoryProvider).createSong(song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Música salva no Firebase!'), backgroundColor: Colors.green),
        );
        ref.read(selectedSongIdProvider.notifier).select(song.id);
        ref.read(isEditorVisibleProvider.notifier).state = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  void _insertText(String text) {
    final textSelection = _contentController.selection;
    if (textSelection.isValid) {
      final newText = _contentController.text.replaceRange(textSelection.start, textSelection.end, text);
      _contentController.text = newText;
      _contentController.selection = TextSelection.collapsed(offset: textSelection.start + text.length);
    } else {
      _contentController.text += text;
    }
  }

  void _showLocalImportDialog(BuildContext context) {
    final urlController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171f33),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Importar do Cifra Club', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cole a URL do Cifra Club abaixo para converter magicamente!', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'https://www.cifraclub.com.br/...',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
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
                  child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final url = urlController.text.trim();
                          if (url.isEmpty) return;

                          setDialogState(() => isLoading = true);

                          try {
                            final chordPro = await CifraClubParser.fetchAndParse(url);
                            
                            ref.read(selectedSongIdProvider.notifier).select(null);
                            ref.read(editingChordProProvider.notifier).state = chordPro;
                            ref.read(isEditorVisibleProvider.notifier).state = true;
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Importado com sucesso!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: colors.primary.withOpacity(0.1), width: 2),
            ),
            child: Icon(
              Icons.music_note_rounded,
              size: 64,
              color: colors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nenhuma Música Selecionada',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Selecione uma música na barra lateral para visualizar os detalhes, transpor tons, ou iniciar a rolagem automática.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showLocalImportDialog(context),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Importar de Link'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: colors.primary.withOpacity(0.08),
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary.withOpacity(0.2)),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.read(selectedSongIdProvider.notifier).select(null);
                  ref.read(editingChordProProvider.notifier).state = '''{title: Nova Música}
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
                label: const Text('Criar Música'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
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
            final matchingSong = ref.read(songListProvider).value?.firstWhere((s) => s.content == next);
            _selectedFolderId = matchingSong?.folderId;
          } catch (_) {
            _selectedFolderId = null;
          }
        });
      }
    });

    final colors = Theme.of(context).colorScheme;
    
    final savedSongs = ref.watch(songListProvider).value ?? [];
    final allSetlists = ref.watch(setlistListProvider).value ?? [];
    
    // Ordena os repertórios colocando os mais recentes (criados por último) no topo
    final sortedSetlists = List<SongSetlist>.from(allSetlists).reversed.toList();
    // Limita a exibição rápida no dropdown para os 10 mais recentes para não poluir a tela
    final setlists = sortedSetlists.take(10).toList();

    final filter = ref.watch(songFilterProvider);
    final activeTab = ref.watch(sidebarTabProvider);

    final filteredSongs = savedSongs.where((song) {
      if (activeTab == SidebarTab.favorites || filter.onlyFavorites) {
        if (!song.isFavorite) return false;
      }
      if (filter.folderId != null) {
        final matchingSetlist = setlists.where((s) => s.id == filter.folderId).firstOrNull;
        if (matchingSetlist != null) {
          final containsSong = matchingSetlist.items.any((item) =>
              item.type == 'song' &&
              item.title.trim().toLowerCase() == song.title.trim().toLowerCase());
          if (!containsSong) return false;
        } else {
          return false;
        }
      }
      if (filter.artist != null) {
        if (song.artist.trim().toLowerCase() != filter.artist!.trim().toLowerCase()) return false;
      }
      return true;
    }).toList();

    final selectedSongId = ref.watch(selectedSongIdProvider);
    final isEditorVisible = ref.watch(isEditorVisibleProvider);
    final showPreview = isEditorVisible || selectedSongId != null;

    Song? currentSavedSong;
    if (selectedSongId != null) {
      try {
        currentSavedSong = savedSongs.firstWhere((s) => s.id == selectedSongId);
      } catch (_) {}
    }
    
    final isSaved = currentSavedSong != null;

    // Compute filter text label
    final String titleLabel = activeTab == SidebarTab.favorites ? 'Favoritos' : 'Músicas';
    String? filterLabel;
    if (filter.folderId != null) {
      final matched = setlists.where((s) => s.id == filter.folderId).firstOrNull;
      filterLabel = matched?.name ?? 'Repertório';
    } else if (filter.artist != null) {
      filterLabel = filter.artist;
    }
    
    return Row(
      children: [
        // Left Column: Songs List
        if (!isEditorVisible)
          Container(
            width: 250,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // slate-800
            border: Border(right: BorderSide(color: colors.outline.withOpacity(0.2))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          titleLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                        ),
                        if (filterLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  filterLabel,
                                  style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    ref.read(songFilterProvider.notifier).clear();
                                  },
                                  child: Icon(Icons.close, size: 14, color: colors.primary),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (activeTab == SidebarTab.songs) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.outline.withOpacity(0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: filter.folderId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF171f33),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            hint: const Text('Filtrar por Repertório', style: TextStyle(color: Colors.white30, fontSize: 12)),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos os Repertórios'),
                              ),
                              ...setlists.map((s) => DropdownMenuItem<String?>(
                                    value: s.id,
                                    child: Text(s.name),
                                  )),
                            ],
                            onChanged: (newFolderId) {
                              ref.read(songFilterProvider.notifier).setFolder(newFolderId);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ref.watch(songListProvider).when(
                  data: (_) {
                    if (filteredSongs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Nenhuma música encontrada.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () {
                                  ref.read(selectedSongIdProvider.notifier).select(null);
                                  ref.read(isEditorVisibleProvider.notifier).state = true;
                                },
                                child: const Text('Criar Nova Música'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final isActive = selectedSongId == song.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              ref.read(selectedSongIdProvider.notifier).select(song.id);
                              ref.read(editingChordProProvider.notifier).state = song.content;
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colors.primary.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isActive
                                    ? Border(left: BorderSide(color: colors.primary, width: 3.5))
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: TextStyle(
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                      color: isActive ? Colors.white : colors.onSurface,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    song.artist,
                                    style: TextStyle(
                                      color: isActive
                                          ? colors.primary.withOpacity(0.8)
                                          : colors.onSurfaceVariant.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
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
                              ref.read(isEditorVisibleProvider.notifier).state = false;
                            },
                          ),
                          const SizedBox(width: 4),
                          Text('EDITOR DE MÚSICA', style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                      isSaved
                          ? TextButton.icon(onPressed: null, icon: const Icon(Icons.check, size: 16), label: const Text('SALVO NO DB'))
                          : TextButton.icon(onPressed: _saveToFirebase, icon: const Icon(Icons.cloud_upload, size: 16), label: const Text('SALVAR NO DB')),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Título da música',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Video URL & Key
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _videoUrlController,
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'URL do Vídeo (YouTube)',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            const Text('Tom original: ', style: TextStyle(color: Colors.white70)),
                            DropdownButton<String>(
                              value: _selectedKey,
                              dropdownColor: colors.surfaceContainerHigh,
                              style: const TextStyle(color: Colors.white),
                              underline: Container(height: 1, color: Colors.white24),
                              items: ['Detectar', 'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']
                                  .map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedKey = v);
                                  _onFieldChanged();
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Artist & Format
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _artistController,
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Artista',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Radio<ChordFormat>(
                                      value: ChordFormat.text,
                                      groupValue: _format,
                                      activeColor: colors.primary,
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _format = v);
                                          _parseChordProToFields(_currentChordPro);
                                        }
                                      },
                                    ),
                                    const Text('Acordes sobre Letras', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Radio<ChordFormat>(
                                      value: ChordFormat.chordPro,
                                      groupValue: _format,
                                      activeColor: colors.primary,
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _format = v);
                                          _parseChordProToFields(_currentChordPro);
                                        }
                                      },
                                    ),
                                    const Text('ChordPro', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Collection Selector dropdown
                        Row(
                          children: [
                            const Text('Repertório / Coleção: ', style: TextStyle(color: Colors.white70)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<String?>(
                                value: currentSavedSong?.folderId ?? _selectedFolderId,
                                isExpanded: true,
                                dropdownColor: colors.surfaceContainerHigh,
                                style: const TextStyle(color: Colors.white),
                                underline: Container(height: 1, color: Colors.white24),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Nenhum Repertório'),
                                  ),
                                  ...setlists.map((col) => DropdownMenuItem<String?>(
                                        value: col.id,
                                        child: Text(col.name),
                                      )),
                                ],
                                onChanged: (v) async {
                                  setState(() => _selectedFolderId = v);
                                  if (currentSavedSong != null) {
                                    final updated = currentSavedSong.copyWith(folderId: v);
                                    await ref.read(songRepositoryProvider).updateSong(updated);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Repertório atualizado!'), backgroundColor: Colors.green),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Toolbar
                        Row(
                          children: [
                            TextButton(onPressed: () => _insertText('{c: Intro}\n'), child: const Text('Intro')),
                            TextButton(onPressed: () => _insertText('{c: Chorus}\n'), child: const Text('Chorus')),
                            TextButton(onPressed: () => _insertText('{c: Verse}\n'), child: const Text('Verse')),
                            TextButton(onPressed: () => _insertText('[]'), child: const Text('Acordes')),
                            const Spacer(),
                            IconButton(icon: const Icon(Icons.undo, color: Colors.white54), onPressed: () {}),
                          ],
                        ),
                        // Main content
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: colors.outline.withOpacity(0.2)),
                              color: colors.surfaceContainerHigh,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: _contentController,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 14,
                                color: Colors.white,
                                height: 1.5,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Cole a letra e os acordes aqui...',
                                hintStyle: TextStyle(color: Colors.white30),
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
        if (isEditorVisible)
          Container(width: 1, color: colors.outline),
          
        // Right Column: Preview
        Expanded(
          flex: isEditorVisible ? 1 : 3,
          child: Container(
            color: const Color(0xFF0b1326),
            child: showPreview
                ? SongViewerScreen(
                    chordProText: _currentChordPro,
                    hideAppBar: true,
                    isPreviewMode: isEditorVisible,
                    isFavorite: currentSavedSong?.isFavorite ?? false,
                    onFavoriteToggle: () {
                      if (currentSavedSong != null) {
                        final updated = currentSavedSong.copyWith(isFavorite: !currentSavedSong.isFavorite);
                        ref.read(songRepositoryProvider).updateSong(updated);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(updated.isFavorite ? 'Adicionado aos Favoritos!' : 'Removido dos Favoritos.'),
                            backgroundColor: updated.isFavorite ? Colors.green : Colors.grey,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Salve a música no banco de dados primeiro!'),
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
