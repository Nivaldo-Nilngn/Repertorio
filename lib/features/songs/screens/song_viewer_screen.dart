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

  Widget _buildAutoScrollOverlay() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withOpacity(0.96),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pause / Resume
          Tooltip(
            message: 'Pausar rolagem',
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _toggleAutoScroll,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pause, size: 22, color: colors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Speed down
          Tooltip(
            message: 'Diminuir velocidade',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _changeScrollSpeed(-0.5),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.remove, size: 18, color: colors.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Slider
          SizedBox(
            width: 130,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: colors.primary,
                inactiveTrackColor: colors.outlineVariant.withOpacity(0.4),
                thumbColor: colors.primary,
              ),
              child: Slider(
                value: _scrollSpeed,
                min: 0.5,
                max: 5.0,
                divisions: 18,
                onChanged: (v) => setState(() => _scrollSpeed = v),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Speed up
          Tooltip(
            message: 'Aumentar velocidade',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _changeScrollSpeed(0.5),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, size: 18, color: colors.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Close / Stop auto-scroll
          Tooltip(
            message: 'Parar rolagem automática',
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _toggleAutoScroll,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 18, color: colors.onErrorContainer),
              ),
            ),
          ),
        ],
      ),
    );
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Left Sidebar
            if (widget.hideAppBar && !widget.isPreviewMode) _buildLeftSidebar(),

            // 2. Center Content (Lyrics) & Floating Right Column (Chords Panel)
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Positioned.fill(
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Actions and indicators will go here without the duplicate buttons
                                        AnimatedBuilder(
                                          animation: _transposeSteps,
                                          builder: (context, _) => _buildTransposeIndicator(),
                                        ),
                                        const SizedBox(height: 24),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: AnimatedBuilder(
                                            animation: Listenable.merge([_fontSize, _transposeSteps, _instrument]),
                                            builder: (context, _) => _buildLyricsContent(),
                                          ),
                                        ),
                                      ],
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
                  if (_showChordsPanel)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_transposeSteps, _instrument]),
                        builder: (context, _) => _buildRightSidebar(),
                      ),
                    ),
                  // Floating auto-scroll speed control
                  if (_isAutoScrolling)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildAutoScrollOverlay()),
                    ),
                ],
              ),
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
                
                _buildSidebarButton(
                  widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                  widget.isFavorite ? 'Cifra favorita' : 'Favoritar cifra',
                  widget.onFavoriteToggle ?? () {},
                  isActive: widget.isFavorite,
                  activeColor: Colors.orange,
                ),
                _buildSidebarButton(Icons.share, 'Compartilhar', () {
                  final url = html.window.location.href;
                  html.window.navigator.clipboard?.writeText(url);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link da cifra copiado para a área de transferência!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }),
                
                // Font Size button custom
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          tooltip: 'Diminuir Fonte',
                          onPressed: () => _changeFontSize(-2),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        const Text('Texto', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          tooltip: 'Aumentar Fonte',
                          onPressed: () => _changeFontSize(2),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Transpose button custom
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          tooltip: 'Diminuir Tom',
                          onPressed: () => _transposeSteps.value--,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        const Text('½ Tom', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          tooltip: 'Aumentar Tom',
                          onPressed: () => _transposeSteps.value++,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
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
                _buildSidebarButton(Icons.print, 'Imprimir', () {
                  html.window.print();
                }),
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

  Widget _buildSidebarButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false, Color? activeColor}) {
    final colors = Theme.of(context).colorScheme;
    final displayColor = isActive ? (activeColor ?? colors.primary) : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: displayColor),
        label: Text(label, style: TextStyle(color: displayColor)),
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? (activeColor ?? colors.primary).withOpacity(0.15) : Colors.transparent,
          side: BorderSide(color: isActive ? (activeColor ?? colors.primary) : colors.outlineVariant.withOpacity(0.5)),
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
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
        border: Border(
          left: BorderSide(color: colors.outlineVariant.withOpacity(0.5)),
        ),
      ),
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
                                key: ValueKey('${chord}_${_instrument.value}'),
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

  // Removed duplicate _buildActionButtons method

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
    final stopwatch = Stopwatch()..start();
    
    final widgetList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _parsedSong.lines.map((line) => _buildLine(line)).toList(),
    );
    
    stopwatch.stop();
    debugPrint('MusiCifras Debug: Cifra renderizada em ${stopwatch.elapsedMicroseconds} µs (${stopwatch.elapsedMilliseconds} ms)');
    
    return widgetList;
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

    // Check if the line has no sung words (empty lyrics meaning chord-only line)
    final isInline = line.isInline;

    if (isInline) {
      final chordsString = _buildInlineChordsString(line).replaceAll(' ', '\u00A0');

      // Extract a section label (e.g. "[Intro]") from the raw lyrics if present
      final sectionMatch = RegExp(r'\[([^\]]+)\]').firstMatch(line.lyrics);
      final sectionLabel = sectionMatch != null ? '[${sectionMatch.group(1)}]' : null;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sectionLabel != null)
              Text(
                sectionLabel,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: _fontSize.value,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              chordsString,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: _fontSize.value,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    return _buildChordLineWidget(line, colorScheme);
  }

  String _buildInlineChordsString(SongLine line) {
    final chordsBuffer = StringBuffer();
    int currentLyricIndex = 0;
    // Remove section markers like [Intro], [Verso], [Ponte] from lyrics
    // before using segments as spacing — they are labels, not lyrics.
    final sectionPattern = RegExp(r'\[[^\]]+\]\s*');

    for (int i = 0; i < line.chords.length; i++) {
      final chordPos = line.chords[i];

      if (chordPos.index > currentLyricIndex) {
        final rawSegment = line.lyrics.substring(currentLyricIndex, chordPos.index);
        // Strip section labels; pad with spaces to keep chord alignment
        final cleanSegment = rawSegment.replaceAll(sectionPattern, '');
        chordsBuffer.write(' ' * cleanSegment.length);
        currentLyricIndex = chordPos.index;
      }

      final displayChord = ChordTransposer.transpose(chordPos.chord, _transposeSteps.value);
      chordsBuffer.write(displayChord);
      chordsBuffer.write(' ');
      currentLyricIndex = chordPos.index;
    }

    if (currentLyricIndex < line.lyrics.length) {
      final remaining = line.lyrics.substring(currentLyricIndex).replaceAll(sectionPattern, '');
      chordsBuffer.write(remaining);
    }

    return chordsBuffer.toString();
  }

  Widget _buildChordLineWidget(SongLine line, ColorScheme colorScheme) {
    final chordsBuffer = StringBuffer();
    final lyricsBuffer = StringBuffer();
    int currentLyricIndex = 0;
    
    for (int i = 0; i < line.chords.length; i++) {
      final chordPos = line.chords[i];
      
      if (chordPos.index > currentLyricIndex) {
        final segment = line.lyrics.substring(currentLyricIndex, chordPos.index);
        lyricsBuffer.write(segment);
        chordsBuffer.write(' ' * segment.length);
        currentLyricIndex = chordPos.index;
      }
      
      int nextChordIndex = (i + 1 < line.chords.length) ? line.chords[i + 1].index : line.lyrics.length;
      String lyricSegment = line.lyrics.substring(currentLyricIndex, nextChordIndex);
      
      final displayChord = ChordTransposer.transpose(chordPos.chord, _transposeSteps.value);
      
      int padLength = 0;
      if (displayChord.length >= lyricSegment.length) {
        padLength = (displayChord.length + 1) - lyricSegment.length;
      }
      
      chordsBuffer.write(displayChord);
      chordsBuffer.write(' ' * (lyricSegment.length + padLength - displayChord.length));
      
      lyricsBuffer.write(lyricSegment);
      lyricsBuffer.write(' ' * padLength);
      
      currentLyricIndex = nextChordIndex;
    }
    
    if (currentLyricIndex < line.lyrics.length) {
      final segment = line.lyrics.substring(currentLyricIndex);
      lyricsBuffer.write(segment);
      chordsBuffer.write(' ' * segment.length);
    }

    final chordsString = chordsBuffer.toString().replaceAll(' ', '\u00A0');
    final lyricsString = lyricsBuffer.toString().replaceAll(' ', '\u00A0');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chordsString,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: _fontSize.value,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          Text(
            lyricsString,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: _fontSize.value,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
