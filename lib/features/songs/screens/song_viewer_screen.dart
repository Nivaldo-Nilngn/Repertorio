import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../models/song.dart';
import '../widgets/chord_api_viewer.dart';
import '../utils/chord_pro_parser.dart';
import '../utils/chord_transposer.dart';
import '../../manager/providers/editor_provider.dart';
import '../../manager/providers/manager_providers.dart';
import '../repositories/song_repository.dart';

class SongViewerScreen extends ConsumerStatefulWidget {
  final String chordProText;
  final bool hideAppBar;
  final bool isPreviewMode;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const SongViewerScreen({
    super.key,
    required this.chordProText,
    this.hideAppBar = false,
    this.isPreviewMode = false,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  ConsumerState<SongViewerScreen> createState() => _SongViewerScreenState();
}

class _SongViewerScreenState extends ConsumerState<SongViewerScreen> {
  late ParsedSong _parsedSong;
  final ValueNotifier<double> _fontSize = ValueNotifier(16.0);
  final ValueNotifier<int> _transposeSteps = ValueNotifier(0);
  final ValueNotifier<String> _instrument = ValueNotifier('guitar');
  
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  double _scrollSpeed = 1.0;
  bool _isAutoScrolling = false;
  bool _showChordsPanel = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _parsedSong = ChordProParser.parse(widget.chordProText);
    _registerVideoIframe();
  }

  void _registerVideoIframe() {
    if (_parsedSong.video.isNotEmpty) {
      final String viewId = 'youtube-iframe-${_parsedSong.video}';
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => html.IFrameElement()
          ..width = '100%'
          ..height = '100%'
          ..src = 'https://www.youtube.com/embed/${_extractYoutubeId(_parsedSong.video)}'
          ..style.border = 'none'
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true,
      );
    }
  }

  @override
  void dispose() {
    _fontSize.dispose();
    _transposeSteps.dispose();
    _instrument.dispose();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _autoScrollTimer?.cancel();
      setState(() => _isAutoScrolling = false);
    } else {
      setState(() => _isAutoScrolling = true);
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final currentScroll = _scrollController.offset;
          if (currentScroll < maxScroll) {
            _scrollController.jumpTo(currentScroll + _scrollSpeed);
          } else {
            _toggleAutoScroll();
          }
        }
      });
    }
  }

  void _changeScrollSpeed(double delta) {
    setState(() {
      _scrollSpeed = (_scrollSpeed + delta).clamp(0.5, 5.0);
    });
  }
  
  void _changeFontSize(double delta) {
    _fontSize.value = (_fontSize.value + delta).clamp(10.0, 48.0);
  }

  @override
  void didUpdateWidget(covariant SongViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chordProText != widget.chordProText) {
      setState(() {
        _parsedSong = ChordProParser.parse(widget.chordProText);
        _registerVideoIframe();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _showChordsPanel = !_showChordsPanel;
          });
        },
        icon: const Icon(Icons.queue_music),
        label: const Text('Acordes'),
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.onSurface,
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Left Sidebar
            if (widget.hideAppBar && !widget.isPreviewMode) _buildLeftSidebar(),

            // 2. Center Content (Lyrics) & Right Column (Video)
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 48.0, bottom: 100.0, left: 32.0, right: 32.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1024),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (widget.hideAppBar) _buildDesktopHeader(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_fontSize, _transposeSteps, _instrument]),
                            builder: (context, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.hideAppBar) _buildActionButtons(),
                                if (widget.hideAppBar) const SizedBox(height: 24),
                                _buildTransposeIndicator(),
                                const SizedBox(height: 24),
                                _buildLyricsContent(),
                              ],
                            ),
                          ),
                        ),
                        if (_parsedSong.video.isNotEmpty) ...[
                          const SizedBox(width: 32),
                          SizedBox(
                            width: 300,
                            child: _buildVideoPlaceholder(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

            // 3. Right Sidebar (Chords Panel)
            if (_showChordsPanel)
              AnimatedBuilder(
                animation: Listenable.merge([_transposeSteps, _instrument]),
                builder: (context, _) => _buildRightSidebar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final colors = Theme.of(context).colorScheme;
    
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Artist Profile Picture
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: colors.surfaceContainerHighest,
              child: const Icon(Icons.person, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView(
              children: [
                _buildSidebarButton(Icons.edit_note, 'Simplificar cifra', () {}),
                _buildSidebarButton(Icons.unfold_more, 'Auto rolagem', _toggleAutoScroll, isActive: _isAutoScrolling),
                
                // Font Size button custom
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                      side: BorderSide(color: colors.outlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      alignment: Alignment.center,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(onTap: () => _changeFontSize(-2), child: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Text('Texto', style: TextStyle(fontWeight: FontWeight.normal)),
                        InkWell(onTap: () => _changeFontSize(2), child: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ),
                
                // Transpose button custom
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                      side: BorderSide(color: colors.outlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      alignment: Alignment.center,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(onTap: () => _transposeSteps.value--, child: const Icon(Icons.remove, size: 16)),
                        const Text('½ Tom', style: TextStyle(fontWeight: FontWeight.normal)),
                        InkWell(onTap: () => _transposeSteps.value++, child: const Icon(Icons.add, size: 16)),
                      ],
                    ),
                  ),
                ),

                _buildSidebarButton(Icons.queue_music, 'Acordes', () {
                  setState(() {
                    _showChordsPanel = !_showChordsPanel;
                  });
                }, isActive: _showChordsPanel),
                _buildSidebarButton(Icons.grid_view, 'Exibir', () {}),
                
                const Divider(height: 32),
                
                _buildSidebarButton(Icons.playlist_add, 'Adicionar à lista', _showAddToCollectionDialog),
                
                const Divider(height: 32),

                _buildSidebarButton(Icons.timer, 'Metrônomo', () {}),
                _buildSidebarButton(Icons.menu_book, 'Dicionário', () {}),
                
                const Divider(height: 32),

                _buildSidebarButton(Icons.edit, 'Corrigir', () {
                  ref.read(isEditorVisibleProvider.notifier).state = !ref.read(isEditorVisibleProvider);
                }),
                _buildSidebarButton(Icons.print, 'Imprimir', () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToCollectionDialog() {
    final colors = Theme.of(context).colorScheme;
    
    // Find the current song by content or title
    final savedSongs = ref.read(songListProvider).value ?? [];
    Song? currentSong;
    try {
      currentSong = savedSongs.firstWhere((s) => s.content == widget.chordProText);
    } catch (_) {
      try {
        currentSong = savedSongs.firstWhere((s) => s.title == _parsedSong.title);
      } catch (_) {}
    }

    if (currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salve a música no banco de dados primeiro!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final collections = ref.read(collectionListProvider).value ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('Adicionar ao Repertório'),
          content: SizedBox(
            width: 300,
            child: ListView(
              shrinkWrap: true,
              children: [
                // Option for No Collection
                ListTile(
                  leading: const Icon(Icons.folder_off),
                  title: const Text('Remover do Repertório'),
                  trailing: currentSong?.folderId == null ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () async {
                    if (currentSong != null) {
                      final updated = currentSong.copyWith(folderId: null);
                      await ref.read(songRepositoryProvider).updateSong(updated);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Removido do repertório!'), backgroundColor: Colors.green),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                // List of collections
                if (collections.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('Nenhuma coleção criada ainda.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                ...collections.map((col) {
                  final isCurrent = currentSong?.folderId == col.id;
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(col.name),
                    trailing: isCurrent ? const Icon(Icons.check, color: Colors.green) : null,
                    onTap: () async {
                      if (currentSong != null) {
                        final updated = currentSong.copyWith(folderId: col.id);
                        await ref.read(songRepositoryProvider).updateSong(updated);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Adicionado a ${col.name}!'), backgroundColor: Colors.green),
                          );
                        }
                      }
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('FECHAR'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebarButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: isActive ? colors.primary : colors.onSurfaceVariant),
        label: Text(label, style: TextStyle(color: isActive ? colors.primary : colors.onSurfaceVariant)),
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? colors.primaryContainer.withOpacity(0.3) : Colors.transparent,
          side: BorderSide(color: isActive ? colors.primary : colors.outlineVariant.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.center, // Center aligned like Cifra Club
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildRightSidebar() {
    final colors = Theme.of(context).colorScheme;
    final Set<String> uniqueChords = {};
    for (var line in _parsedSong.lines) {
      for (var chordPos in line.chords) {
        uniqueChords.add(chordPos.chord);
      }
    }
    
    final List<String> transposedChords = uniqueChords
        .map((chord) => ChordTransposer.transpose(chord, _transposeSteps.value))
        .toList();

    return Container(
      color: colors.surfaceContainerLowest,
      width: 280,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Acordes da Música', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              InkWell(
                onTap: () {
                  _instrument.value = _instrument.value == 'piano' ? 'guitar' : 'piano';
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_instrument.value == 'piano' ? 'Teclado' : 'Violão/Guitarra', style: const TextStyle(fontSize: 14)),
                      Icon(Icons.swap_vert, size: 16, color: colors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: transposedChords.isEmpty 
                  ? const Center(child: Text('Nenhum acorde', style: TextStyle(color: Colors.grey)))
                  : ListView(
                      children: transposedChords
                          .map((chord) => Padding(
                                padding: const EdgeInsets.only(bottom: 24.0),
                                child: Column(
                                  children: [
                                    Text(chord, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onSurface)),
                                    const SizedBox(height: 8),
                                    _buildChordDiagramPlaceholder(chord, _instrument.value),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChordDiagramPlaceholder(String chordName, String instrument) {
    String cleanChord = chordName.replaceAll('7M', 'maj7')
                          .replaceAll('º', 'dim')
                          .replaceAll('°', 'dim')
                          .replaceAll('-', 'm')
                          .replaceAll('+', 'aug')
                          .split('/')[0];
                          
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: ChordApiViewer(
          key: ValueKey('${cleanChord}_$instrument'),
          chord: cleanChord, 
          instrument: instrument,
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.hardEdge,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: HtmlElementView(viewType: 'youtube-iframe-${_parsedSong.video}'),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.start,
        spacing: 32,
        runSpacing: 24,
        children: [
          // Left side: Title, Artist, Actions
          Container(
            constraints: const BoxConstraints(minWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 16,
                  children: [
                    Text(
                      _parsedSong.title.isNotEmpty ? _parsedSong.title : 'Música Sem Título',
                      style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _parsedSong.artist.isNotEmpty ? _parsedSong.artist : 'Artista',
                  style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.verified, size: 18),
          label: const Text('Cifra: Principal (Violão e Guitarra)', style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outlineVariant),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onFavoriteToggle,
          icon: Icon(widget.isFavorite ? Icons.favorite : Icons.favorite_border, size: 18),
          label: Text(widget.isFavorite ? 'Cifra favorita' : 'Favoritar Cifra', style: const TextStyle(fontWeight: FontWeight.bold)),
          style: widget.isFavorite
              ? OutlinedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                )
              : OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
        ),
      ],
    );
  }

  String _extractYoutubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    }
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'] ?? '';
    }
    return '';
  }
  
  Widget _buildTransposeIndicator() {
     final colorScheme = Theme.of(context).colorScheme;
     return Text.rich(
        TextSpan(
          text: 'Tom: ',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: colorScheme.onSurfaceVariant),
          children: [
            TextSpan(
              text: ChordTransposer.transpose(_parsedSong.key, _transposeSteps.value),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary),
            ),
          ],
        ),
     );
  }

  Widget _buildLyricsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _parsedSong.lines.map((line) => _buildLine(line)).toList(),
    );
  }

  Widget _buildLine(SongLine line) {
    final colorScheme = Theme.of(context).colorScheme;

    if (line.type == 'comment') {
      return Padding(
        padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
        child: Text(
          line.lyrics,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: _fontSize.value,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (line.chords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          line.lyrics.isEmpty ? ' ' : line.lyrics,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: _fontSize.value,
            color: colorScheme.onSurface,
          ),
        ),
      );
    }

    // Check if the line has no sung words (only brackets/section markers or spaces)
    final lyricsWithoutBrackets = line.lyrics.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    final isInline = lyricsWithoutBrackets.isEmpty;

    if (isInline) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: _buildInlineBlocks(line, colorScheme),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: _buildChordBlocks(line, colorScheme),
      ),
    );
  }

  List<Widget> _buildInlineBlocks(SongLine line, ColorScheme colorScheme) {
    List<Widget> blocks = [];
    int currentLyricIndex = 0;
    
    for (int i = 0; i < line.chords.length; i++) {
      final chordPos = line.chords[i];
      
      if (chordPos.index > currentLyricIndex) {
        blocks.add(
          Text(
            line.lyrics.substring(currentLyricIndex, chordPos.index).replaceAll(' ', '\u00A0'),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: _fontSize.value,
              color: colorScheme.onSurface,
            ),
          ),
        );
        currentLyricIndex = chordPos.index;
      }
      
      final displayChord = ChordTransposer.transpose(chordPos.chord, _transposeSteps.value);

      blocks.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text(
            displayChord,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: _fontSize.value,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }
    
    if (currentLyricIndex < line.lyrics.length) {
      blocks.add(
        Text(
          line.lyrics.substring(currentLyricIndex).replaceAll(' ', '\u00A0'),
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: _fontSize.value,
            color: colorScheme.onSurface,
          ),
        ),
      );
    }

    return blocks;
  }

  List<Widget> _buildChordBlocks(SongLine line, ColorScheme colorScheme) {
    List<Widget> blocks = [];
    int currentLyricIndex = 0;
    
    for (int i = 0; i < line.chords.length; i++) {
      final chordPos = line.chords[i];
      
      if (chordPos.index > currentLyricIndex) {
        blocks.add(
          Text(
            line.lyrics.substring(currentLyricIndex, chordPos.index),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: _fontSize.value,
              color: colorScheme.onSurface,
            ),
          ),
        );
        currentLyricIndex = chordPos.index;
      }
      
      int nextChordIndex = (i + 1 < line.chords.length) ? line.chords[i + 1].index : line.lyrics.length;
      String lyricSegment = line.lyrics.substring(currentLyricIndex, nextChordIndex);
      
      final displayChord = ChordTransposer.transpose(chordPos.chord, _transposeSteps.value);

      // Pad the lyric segment if the chord is wider, so chords don't touch each other
      if (displayChord.length >= lyricSegment.length) {
        lyricSegment = lyricSegment.padRight(displayChord.length + 1, '\u00A0');
      }
      // Replace normal spaces with non-breaking spaces so Flutter Text layout doesn't trim trailing spaces
      lyricSegment = lyricSegment.replaceAll(' ', '\u00A0');

      blocks.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayChord,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: _fontSize.value,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary, // Using primary theme color for chords!
              ),
            ),
            Text(
              lyricSegment.isEmpty ? '\u00A0' : lyricSegment,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: _fontSize.value,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
      currentLyricIndex = nextChordIndex;
    }
    
    if (currentLyricIndex < line.lyrics.length) {
      blocks.add(
        Text(
          line.lyrics.substring(currentLyricIndex),
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: _fontSize.value,
            color: colorScheme.onSurface,
          ),
        ),
      );
    }

    return blocks;
  }
}
