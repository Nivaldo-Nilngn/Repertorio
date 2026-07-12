import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../models/song.dart';

import '../widgets/chord_api_viewer.dart';
import '../utils/chord_pro_parser.dart';
import '../utils/chord_transposer.dart';
import '../../manager/providers/editor_provider.dart';
import '../repositories/song_repository.dart';
import '../../midi/providers/midi_providers.dart';
import '../../../core/theme/settings_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';

enum VideoDisplayState { full, mini, hidden }

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
  final ValueNotifier<String> _instrument = ValueNotifier('piano');
  
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  double _scrollSpeed = 1.0;
  bool _isAutoScrolling = false;
  bool _showChordsPanel = false;
  bool _isRoadmapMode = true;
  bool _isMultiColumn = false;
  late bool _isFavoriteLocal;

  bool _showFab = true;
  Timer? _fabTimer;

  void _startFabTimer() {
    _fabTimer?.cancel();
    _fabTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isAutoScrolling && !_isFabPinned) {
        setState(() => _showFab = false);
      }
    });
  }

  bool _isFabPinned = false;
  
  void _toggleFabPin() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFabPinned = !_isFabPinned;
      if (_isFabPinned) {
        _showFab = true;
        _fabTimer?.cancel();
      } else {
        _startFabTimer();
      }
    });
  }

  void _onScroll() {
    if (_isAutoScrolling) return;
    if (!_showFab) {
      setState(() => _showFab = true);
    }
    _startFabTimer();
  }

  // Video 3-state: full → mini controller → hidden
  VideoDisplayState _videoState = VideoDisplayState.full;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _isFavoriteLocal = widget.isFavorite;
    _parsedSong = ChordProParser.parse(widget.chordProText);
    _registerVideoIframe();
    _fontSize.value = (ref.read(settingsProvider).defaultFontSize + 2.0).clamp(10.0, 48.0);
    _scrollController.addListener(_onScroll);
    _startFabTimer();
  }

  html.IFrameElement? _youtubeIframe;

  // Track registered view factories across hot restarts
  static final Set<String> _registeredViewIds = {};

  void _registerVideoIframe() {
    if (_parsedSong.video.isNotEmpty) {
      final String viewId = 'youtube-iframe-${_parsedSong.video}';
      final videoId = _extractYoutubeId(_parsedSong.video);

      // Create the iframe element regardless (we always want a fresh reference)
      _youtubeIframe = html.IFrameElement()
        ..width = '100%'
        ..height = '100%'
        ..src = 'https://www.youtube.com/embed/$videoId?enablejsapi=1&autoplay=0'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
        ..allowFullscreen = true;

      // Only register the factory once per session (hot restart safe)
      if (!_registeredViewIds.contains(viewId)) {
        _registeredViewIds.add(viewId);
        try {
          // ignore: undefined_prefixed_name
          ui_web.platformViewRegistry.registerViewFactory(
            viewId,
            (int id) => _youtubeIframe!,
          );
        } catch (_) {
          // Already registered — safe to ignore
        }
      }
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _fabTimer?.cancel();
    _scrollController.dispose();
    _fontSize.dispose();
    _transposeSteps.dispose();
    _instrument.dispose();
    super.dispose();
  }

  void _toggleAutoScroll() {
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
    setState(() {
      _scrollSpeed = (_scrollSpeed + delta).clamp(0.5, 5.0);
    });
  }

  Widget _buildAutoScrollOverlay() {
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final sliderMaxWidth = (screenWidth - 220).clamp(50.0, 130.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
            const SizedBox(width: 8),
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
            const SizedBox(width: 6),
            // Slider
            SizedBox(
              width: sliderMaxWidth,
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
            const SizedBox(width: 6),
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
            const SizedBox(width: 8),
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
      ),
    );
  }
  
  void _changeFontSize(double delta) {
    HapticFeedback.lightImpact();
    _fontSize.value = (_fontSize.value + delta).clamp(10.0, 48.0);
  }

  void _changeTranspose(int delta) {
    HapticFeedback.lightImpact();
    _transposeSteps.value += delta;
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
    if (oldWidget.isFavorite != widget.isFavorite) {
      setState(() {
        _isFavoriteLocal = widget.isFavorite;
      });
    }
  }


  void _scrollBy(double offset) {
    if (_scrollController.hasClients) {
      final currentScroll = _scrollController.offset;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final target = (currentScroll + offset).clamp(0.0, maxScroll);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleMidiAction(String action) {
    switch (action) {
      case 'toggle_scroll':
        _toggleAutoScroll();
        break;
      case 'speed_up':
        _changeScrollSpeed(0.5);
        break;
      case 'speed_down':
        _changeScrollSpeed(-0.5);
        break;
      case 'scroll_up':
        _scrollBy(-200);
        break;
      case 'scroll_down':
        _scrollBy(200);
        break;
      case 'tone_up':
        _changeTranspose(1);
        break;
      case 'tone_down':
        _changeTranspose(-1);
        break;
      // next_song and prev_song can be implemented later by notifying the manager
    }
  }

  Widget _buildPinnedBottomBar(ColorScheme colors) {
    return BottomAppBar(
      color: colors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Font size
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TEXTO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.remove, size: 20), onPressed: () => _changeFontSize(-2), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () => _changeFontSize(2), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ],
          ),
          // Transpose
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TOM', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.remove, size: 20), onPressed: () => _changeTranspose(-1), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () => _changeTranspose(1), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ],
          ),
          // Rolagem
          IconButton(icon: Icon(Icons.unfold_more, color: _isAutoScrolling ? colors.primary : colors.onSurfaceVariant), onPressed: _toggleAutoScroll),
          // Dicionario
          IconButton(icon: Icon(Icons.menu_book, color: colors.onSurfaceVariant), onPressed: _showChordsDictionaryDialog),
          // Unpin
          IconButton(icon: Icon(Icons.push_pin, color: colors.primary), onPressed: _toggleFabPin),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(midiActionStreamProvider, (previous, next) {
      if (next != null) {
        _handleMidiAction(next);
      }
    });

    final colors = Theme.of(context).colorScheme;

    // Layout responsivo
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (!isDesktop) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: widget.hideAppBar ? Colors.transparent : colors.surface,
            appBar: widget.hideAppBar ? null : AppBar(
          backgroundColor: colors.surfaceContainer,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _parsedSong.title.isNotEmpty ? _parsedSong.title : 'Música',
                style: TextStyle(color: colors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _parsedSong.artist.isNotEmpty ? _parsedSong.artist : '',
                style: TextStyle(color: colors.primary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            // View Mode Toggle
            IconButton(
              icon: Icon(
                _isRoadmapMode ? Icons.notes : Icons.grid_view,
                color: _isRoadmapMode ? colors.primary : colors.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  _isRoadmapMode = !_isRoadmapMode;
                });
              },
              tooltip: _isRoadmapMode ? 'Ver Cifra Completa' : 'Ver Mapa do Arranjo',
            ),
            // Favorite toggle
            if (widget.onFavoriteToggle != null)
              IconButton(
                icon: Icon(
                  _isFavoriteLocal ? Icons.favorite : Icons.favorite_border,
                  color: _isFavoriteLocal ? Colors.orange : colors.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() {
                    HapticFeedback.lightImpact();
                      _isFavoriteLocal = !_isFavoriteLocal;
                  });
                  widget.onFavoriteToggle!();
                },
                tooltip: _isFavoriteLocal ? 'Remover dos favoritos' : 'Favoritar',
              ),
            // Auto-scroll toggle
            IconButton(
              icon: Icon(
                _isAutoScrolling ? Icons.pause_circle : Icons.play_circle_outline,
                color: _isAutoScrolling ? colors.primary : colors.onSurfaceVariant,
              ),
              onPressed: _toggleAutoScroll,
              tooltip: 'Auto rolagem',
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata cards (Tom & Ritmo)
                  AnimatedBuilder(
                    animation: _transposeSteps,
                    builder: (context, _) => _buildTomBadge(),
                  ),
                  const SizedBox(height: 16),
                  // Video if present (mobile - full only)
                  if (_parsedSong.video.isNotEmpty && _videoState == VideoDisplayState.full) ...[
                    _buildVideoPlaceholder(),
                    const SizedBox(height: 16),
                  ],
                  // Content (Lyrics or Roadmap)
                  AnimatedBuilder(
                    animation: Listenable.merge([_fontSize, _transposeSteps, _instrument]),
                    builder: (context, _) {
                      final child = _isRoadmapMode
                          ? _buildRoadmapContent()
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildLyricsContent(),
                            );
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: child,
                      );
                    },
                  ),
                ],
              ),
            ),
            // Auto-scroll overlay
            if (_isAutoScrolling)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(child: _buildAutoScrollOverlay()),
              ),
          ],
        ),
        bottomNavigationBar: _isFabPinned ? _buildPinnedBottomBar(colors) : null,
        floatingActionButton: _isFabPinned ? null : IgnorePointer(
          ignoring: !_showFab,
          child: AnimatedOpacity(
            opacity: _showFab ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Font Size Control Tile
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    border: Border.all(color: colors.outlineVariant.withOpacity(0.2), width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 4),
                      Text('TEXTO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant)),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _startFabTimer();
                                  _changeFontSize(-2);
                                },
                                child: Center(
                                  child: Icon(Icons.remove, size: 16, color: colors.onSurfaceVariant),
                                ),
                              ),
                            ),
                            VerticalDivider(width: 1, color: colors.outlineVariant.withOpacity(0.2), indent: 4, endIndent: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _startFabTimer();
                                  _changeFontSize(2);
                                },
                                child: Center(
                                  child: Icon(Icons.add, size: 16, color: colors.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Compact Transpose Control Tile
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    border: Border.all(color: colors.outlineVariant.withOpacity(0.2), width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 4),
                      Text('TOM', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant)),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _startFabTimer();
                                  _changeTranspose(-1);
                                },
                                child: Center(
                                  child: Icon(Icons.remove, size: 16, color: colors.onSurfaceVariant),
                                ),
                              ),
                            ),
                            VerticalDivider(width: 1, color: colors.outlineVariant.withOpacity(0.2), indent: 4, endIndent: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _startFabTimer();
                                  _changeTranspose(1);
                                },
                                child: Center(
                                  child: Icon(Icons.add, size: 16, color: colors.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFloatingTile(Icons.unfold_more, 'Rolagem', _toggleAutoScroll, colors),
                _buildFloatingTile(Icons.menu_book, 'Dicionário', _showChordsDictionaryDialog, colors),
                _buildFloatingTile(Icons.push_pin_outlined, 'Fixar', _toggleFabPin, colors),
              ],
            ),
          ),
        ),
      );
        }

        // Desktop layout
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
                                        AnimatedBuilder(
                                          animation: Listenable.merge([_fontSize, _transposeSteps, _instrument]),
                                          builder: (context, _) {
                                            final child = _isRoadmapMode
                                                ? _buildRoadmapContent()
                                                : SingleChildScrollView(
                                                    scrollDirection: Axis.horizontal,
                                                    child: _buildLyricsContent(),
                                                  );
                                            return AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 300),
                                              transitionBuilder: (Widget child, Animation<double> animation) {
                                                return FadeTransition(opacity: animation, child: child);
                                              },
                                              child: child,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
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
                  // ── Keep iframe in DOM always when not hidden (audio continuity) ──
                  if (_parsedSong.video.isNotEmpty && _videoState != VideoDisplayState.hidden)
                    Positioned(
                      top: 12,
                      right: _showChordsPanel ? 320 : 12,
                      // In mini mode: render iframe invisible (Offstage keeps it in DOM = audio plays)
                      // In full mode: render iframe visible
                      child: _videoState == VideoDisplayState.full
                          ? _buildFloatingVideoPlayer()
                          : IgnorePointer(
                              child: Opacity(
                                opacity: 0.01,
                                child: SizedBox(
                                  width: 240,
                                  height: 135,
                                  child: _buildVideoPlaceholder(),
                                ),
                              ),
                            ),
                    ),
                  // ── Mini player UI overlay (shown on top when in mini mode) ──
                  if (_parsedSong.video.isNotEmpty && _videoState == VideoDisplayState.mini)
                    Positioned(
                      top: 12,
                      right: _showChordsPanel ? 320 : 12,
                      child: _buildMiniVideoController(),
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
      },
    );
  }

  Widget _buildFloatingTile(IconData icon, String label, VoidCallback onTap, ColorScheme colors, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: InkWell(
        onTap: () {
          _startFabTimer();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isActive ? colors.primary.withOpacity(0.15) : colors.surfaceContainer,
            border: Border.all(
              color: isActive ? colors.primary : colors.outlineVariant.withOpacity(0.2), 
              width: 1.5
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isActive ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isActive ? colors.primary : colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final colors = Theme.of(context).colorScheme;
    
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(right: BorderSide(color: colors.outlineVariant.withOpacity(0.2))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSidebarTile(
                  icon: Icons.auto_fix_high,
                  label: 'Editar',
                  onTap: () {
                    ref.read(isEditorVisibleProvider.notifier).state = !ref.read(isEditorVisibleProvider);
                  },
                  isActive: ref.watch(isEditorVisibleProvider),
                ),
                _buildSidebarTile(
                  icon: Icons.unfold_more,
                  label: 'Rolagem',
                  onTap: _toggleAutoScroll,
                  isActive: _isAutoScrolling,
                ),
                
                // Compact Font Size Control Tile
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.2), width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Text('TEXTO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant)),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _changeFontSize(-2),
                                  child: Center(
                                    child: Icon(Icons.remove, size: 18, color: colors.onSurfaceVariant),
                                  ),
                                ),
                              ),
                              VerticalDivider(width: 1, color: colors.outlineVariant.withOpacity(0.2), indent: 4, endIndent: 4),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _changeFontSize(2),
                                  child: Center(
                                    child: Icon(Icons.add, size: 18, color: colors.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Compact Transpose Control Tile
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.2), width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Text('TOM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant)),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _changeTranspose(-1),
                                  child: Center(
                                    child: Icon(Icons.remove, size: 18, color: colors.onSurfaceVariant),
                                  ),
                                ),
                              ),
                              VerticalDivider(width: 1, color: colors.outlineVariant.withOpacity(0.2), indent: 4, endIndent: 4),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _changeTranspose(1),
                                  child: Center(
                                    child: Icon(Icons.add, size: 18, color: colors.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                _buildSidebarTile(
                  icon: Icons.music_note,
                  label: 'Acordes',
                  onTap: () {
                    setState(() {
                      _showChordsPanel = !_showChordsPanel;
                    });
                  },
                  isActive: _showChordsPanel,
                ),
                
                if (_parsedSong.video.isNotEmpty)
                  _buildSidebarTile(
                    icon: _videoState == VideoDisplayState.full
                        ? Icons.ondemand_video
                        : _videoState == VideoDisplayState.mini
                            ? Icons.audio_file
                            : Icons.videocam_off,
                    label: _videoState == VideoDisplayState.full
                        ? 'Vídeo'
                        : _videoState == VideoDisplayState.mini
                            ? 'Mini'
                            : 'Oculto',
                    onTap: () {
                      setState(() {
                        _videoState = _videoState == VideoDisplayState.full
                            ? VideoDisplayState.mini
                            : _videoState == VideoDisplayState.mini
                                ? VideoDisplayState.hidden
                                : VideoDisplayState.full;
                      });
                    },
                    isActive: _videoState != VideoDisplayState.hidden,
                  ),

                if (widget.onFavoriteToggle != null)
                  _buildSidebarTile(
                    icon: _isFavoriteLocal ? Icons.favorite : Icons.favorite_border,
                    label: 'Favorito',
                    onTap: () {
                      setState(() {
                        HapticFeedback.lightImpact();
                      _isFavoriteLocal = !_isFavoriteLocal;
                      });
                      widget.onFavoriteToggle!();
                    },
                    isActive: _isFavoriteLocal,
                  ),

                _buildSidebarTile(
                  icon: Icons.view_column,
                  label: 'Colunas',
                  onTap: () {
                    setState(() {
                      _isMultiColumn = !_isMultiColumn;
                    });
                  },
                  isActive: _isMultiColumn,
                ),
                
                _buildSidebarTile(
                  icon: Icons.playlist_add,
                  label: 'Lista',
                  onTap: _showAddToCollectionDialog,
                ),
                
                _buildSidebarTile(
                  icon: Icons.menu_book,
                  label: 'Dicionário',
                  onTap: _showChordsDictionaryDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: isActive 
                ? colors.primary.withOpacity(0.15) 
                : Colors.transparent,
            border: Border.all(
              color: isActive 
                  ? colors.primary 
                  : colors.outlineVariant.withOpacity(0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: isActive ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? colors.primary : colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
  List<String> _getTransposedChords() {
    final Set<String> uniqueChords = {};
    for (var line in _parsedSong.lines) {
      for (var chordPos in line.chords) {
        uniqueChords.add(chordPos.chord);
      }
    }
    
    return uniqueChords
        .map((chord) => ChordTransposer.transpose(chord, _transposeSteps.value))
        .toList();
  }

  void _showChordsDictionaryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        
        return ValueListenableBuilder<String>(
          valueListenable: _instrument,
          builder: (context, currentInstrument, _) {
            final transposedChords = _getTransposedChords();
            return AlertDialog(
              backgroundColor: colors.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dicionário de Acordes',
                    style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      // Instrument switcher inside modal!
                      TextButton.icon(
                        icon: Icon(
                          currentInstrument == 'piano' ? Icons.piano : Icons.music_note,
                          size: 16,
                          color: colors.primary,
                        ),
                        label: Text(
                          currentInstrument == 'piano' ? 'Teclado' : 'Violão/Guitarra',
                          style: TextStyle(color: colors.primary, fontSize: 13),
                        ),
                        onPressed: () {
                          _instrument.value = currentInstrument == 'piano' ? 'guitar' : 'piano';
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.7,
                child: transposedChords.isEmpty
                    ? const Center(child: Text('Nenhum acorde encontrado nesta música.', style: TextStyle(color: Colors.grey)))
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: currentInstrument == 'piano' ? 320 : 220,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: currentInstrument == 'piano' ? 1.6 : 0.7,
                        ),
                        itemCount: transposedChords.length,
                        itemBuilder: (context, index) {
                          final chord = transposedChords[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.outlineVariant.withOpacity(0.3)),
                            ),
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Text(
                                  chord,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _buildChordDiagramPlaceholder(chord, currentInstrument),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRightSidebar() {
    final colors = Theme.of(context).colorScheme;
    final List<String> transposedChords = _getTransposedChords();

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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340), // Limita o tamanho máximo na tela
        child: Container(
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
        ),
      ),
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

  Widget _buildTomBadge() {
    String tomDisplay = '';
    if (_parsedSong.title.toUpperCase().contains('UMA NOVA HISTÓRIA')) {
      final currentKey = ChordTransposer.transpose('F#m', _transposeSteps.value);
      final shapeKey = ChordTransposer.transpose('Em', _transposeSteps.value);
      tomDisplay = '$currentKey (Original, capo 2ª casa, forma de $shapeKey)';
      if (_transposeSteps.value != 0) {
        final offsetSign = _transposeSteps.value > 0 ? '+${_transposeSteps.value}' : '${_transposeSteps.value}';
        tomDisplay = '$currentKey (Original: F#m, capo 2ª casa, forma de $shapeKey | $offsetSign)';
      }
    } else {
      final originalKey = _parsedSong.key.isNotEmpty ? _parsedSong.key : 'C';
      final currentKey = ChordTransposer.transpose(originalKey, _transposeSteps.value);
      
      String capoText = '';
      if (_parsedSong.capo.isNotEmpty) {
        capoText = 'capo ${_parsedSong.capo}ª casa';
        if (_parsedSong.shape.isNotEmpty) {
          final shapeTransposed = ChordTransposer.transpose(_parsedSong.shape, _transposeSteps.value);
          capoText += ', forma de $shapeTransposed';
        }
      }
      
      tomDisplay = capoText.isNotEmpty ? '$currentKey ($capoText)' : currentKey;
      if (_transposeSteps.value != 0) {
        final offsetSign = _transposeSteps.value > 0 ? '+${_transposeSteps.value}' : '${_transposeSteps.value}';
        if (capoText.isNotEmpty) {
          tomDisplay = '$currentKey ($capoText | Tom Original: $originalKey | $offsetSign)';
        } else {
          tomDisplay = '$currentKey (Tom Original: $originalKey | $offsetSign)';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100), // Solid deep orange
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TOM: ',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13),
          ),
          Text(
            tomDisplay,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Title, Artist, actions, Tom Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _parsedSong.title.isNotEmpty ? _parsedSong.title : 'Música Sem Título',
                        style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _parsedSong.artist.isNotEmpty ? _parsedSong.artist : 'Artista',
                  style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _transposeSteps,
                  builder: (context, _) => _buildTomBadge(),
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildFloatingVideoPlayer() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      color: Colors.black,
      child: Container(
        width: 240,
        height: 135,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _buildVideoPlaceholder(),
      ),
    );
  }

  Widget _buildMiniVideoController() {
    // Fallback temporário para o Youtube padrão enquanto o backend está desabilitado
    return Transform.scale(
      scale: 0.7,
      alignment: Alignment.topRight,
      child: _buildFloatingVideoPlayer(),
    );
  }

  Widget _buildRoadmapContent() {
    if (_parsedSong.title.toUpperCase().contains('UMA NOVA HISTÓRIA')) {
      return _buildMockedRoadmap();
    }

    final sections = SongRoadmapBuilder.build(_parsedSong);

    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Text(
          'Nenhuma seção estruturada encontrada para esta música.\nEscreva {c: Introdução} ou similares para criar o mapa.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    if (_isMultiColumn) {
      final leftColumnSections = <SongSection>[];
      final rightColumnSections = <SongSection>[];
      final int half = (sections.length / 2).ceil();
      for (int i = 0; i < sections.length; i++) {
        if (i < half) {
          leftColumnSections.add(sections[i]);
        } else {
          rightColumnSections.add(sections[i]);
        }
      }
      
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: leftColumnSections.map((section) => _buildRoadmapSection(section)).toList(),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rightColumnSections.map((section) => _buildRoadmapSection(section)).toList(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) => _buildRoadmapSection(section)).toList(),
    );
  }

  Widget _buildMockedRoadmap() {
    final colors = Theme.of(context).colorScheme;

    String t(String chord) {
      return ChordTransposer.transpose(chord, _transposeSteps.value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. INTRODUÇÃO
        _buildMockSection(
          title: 'INTRODUÇÃO',
          headerColor: const Color(0xFF5B21B6), // Deep Purple
          rows: [
            _buildMockRow(
              chords: [t('Em'), t('D'), t('Em'), t('D')],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. PRIMEIRA PARTE
        _buildMockSection(
          title: 'PRIMEIRA PARTE',
          headerColor: const Color(0xFF1E3A8A), // Dark Blue
          repetition: '2x',
          rows: [
            _buildMockRow(
              hint: 'Sai de tua tenda...',
              chords: [t('Em'), t('D'), t('A9'), t('C9')],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. SEGUNDA PARTE
        _buildMockSection(
          title: 'SEGUNDA PARTE',
          headerColor: const Color(0xFF1E3A8A), // Dark Blue
          rows: [
            _buildMockRow(
              hint: 'Será que podes contar...',
              chords: [t('Em'), t('D'), t('A9'), t('C9'), t('Em'), t('D'), t('A9')],
            ),
            _buildMockRow(
              hint: 'Tudo aquilo que sonhei...',
              chords: [t('C9'), t('Em'), t('D'), t('C9')],
            ),
            _buildMockRow(
              hint: 'Minha bênção será...',
              chords: [t('A9'), t('C9')],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. REFRÃO
        _buildMockSection(
          title: 'REFRÃO',
          headerColor: const Color(0xFF065F46), // Dark Green
          repetition: '3x',
          rows: [
            _buildMockRow(
              hint: 'Uma nova história...',
              customRow: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCell('${t('G')}  ${t('C9')}'),
                  ),
                  Container(width: 1.5, color: colors.outline.withOpacity(0.3)),
                  Expanded(
                    flex: 1,
                    child: _buildCell(t('D')),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 5. INSTRUMENTAL
        _buildMockSection(
          title: 'INSTRUMENTAL',
          headerColor: const Color(0xFF5B21B6), // Deep Purple
          rows: [
            _buildMockRow(
              chords: [t('Em'), t('D'), t('Em'), t('D')],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 6. OBS 1
        _buildMockObs('Volta ➔ Primeira Parte / Segunda Parte / Refrão'),
        const SizedBox(height: 20),

        // 7. REFRÃO 2
        _buildMockSection(
          title: 'REFRÃO',
          headerColor: const Color(0xFF065F46), // Dark Green
          repetition: '3x',
          rows: [
            _buildMockRow(
              hint: 'Uma nova história...',
              customRow: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCell('${t('G')}  ${t('C9')}'),
                  ),
                  Container(width: 1.5, color: colors.outline.withOpacity(0.3)),
                  Expanded(
                    flex: 1,
                    child: _buildCell(t('D')),
                  ),
                ],
              ),
            ),
            _buildMockRow(
              hint: 'Te abençoarei...',
              chords: [t('G')],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 8. OBS 2
        _buildMockObs('Repete o Refrão 2x ou mais.'),
        const SizedBox(height: 32),

        // 9. Footer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.music_note, size: 16, color: Colors.white30),
            SizedBox(width: 16),
            Text(
              'PROFESSOR ADRIANO MÁRCIO',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            SizedBox(width: 16),
            Icon(Icons.music_note, size: 16, color: Colors.white30),
          ],
        ),
      ],
    );
  }

  Widget _buildMockSection({
    required String title,
    required Color headerColor,
    String? repetition,
    required List<Widget> rows,
  }) {
    final colors = Theme.of(context).colorScheme;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outline.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: _fontSize.value - 3.0,
                    letterSpacing: 1.0,
                  ),
                ),
                if (repetition != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      repetition,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: _fontSize.value - 4.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockRow({
    String? hint,
    List<String>? chords,
    Widget? customRow,
  }) {
    final colors = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                hint,
                style: TextStyle(
                  color: _getLyricColor(),
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (customRow != null)
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.outline.withOpacity(0.3)),
              ),
              child: IntrinsicHeight(child: customRow),
            )
          else if (chords != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final blockWidth = (constraints.maxWidth - (8.0 * 4)) / 5;
                return Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: chords.map((chord) => _buildCell(chord, blockWidth)).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCell(String chord, [double? width]) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          chord,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: _fontSize.value - 6.0,
            fontWeight: FontWeight.bold,
            color: _getChordColor(),
          ),
        ),
      ),
    );
  }

  Color _getChordColor() {
    final currentTheme = ref.watch(appThemeProvider);
    if (currentTheme == AppThemeType.custom) {
      final settings = ref.watch(settingsProvider);
      if (settings.customChordColorHex != null) {
        try {
          return Color(int.parse(settings.customChordColorHex!.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _getLyricColor() {
    final currentTheme = ref.watch(appThemeProvider);
    if (currentTheme == AppThemeType.custom) {
      final settings = ref.watch(settingsProvider);
      if (settings.customLyricColorHex != null) {
        try {
          return Color(int.parse(settings.customLyricColorHex!.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
    }
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildMockObs(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE5A93B).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5A93B), width: 1.5),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: const Color(0xFFE5A93B), fontSize: _fontSize.value - 3.0, fontWeight: FontWeight.w500),
          children: [
            const TextSpan(text: 'OBS:  ', style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapSection(SongSection section) {
    final colors = Theme.of(context).colorScheme;

    if (section.isObs) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: _buildMockObs(section.obsText ?? ""),
      );
    }

    final badgeColor = _getSectionColor(section.title);

    // Extract repetition multiplier to the right of the header bar if it is a single-row section
    final sectionRepetition = (section.rows.length == 1 && section.rows.first.repetition != null)
        ? section.rows.first.repetition
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outline.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            color: badgeColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  section.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: _fontSize.value - 3.0,
                    letterSpacing: 1.0,
                  ),
                ),
                if (sectionRepetition != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sectionRepetition,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: _fontSize.value - 4.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: section.rows.map((row) {
                // If this row's repetition is already shown in the header, hide it from the row
                final hideRowRepetition = (section.rows.length == 1);
                return _buildRoadmapRow(row, hideRowRepetition: hideRowRepetition);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapRow(RoadmapRow row, {bool hideRowRepetition = false}) {
    final colors = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hint/Lyric prompt
          if (row.hint != null && row.hint!.replaceAll(RegExp(r'[()\s/|]'), '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                row.hint!,
                  style: TextStyle(
                    color: _getLyricColor(),
                    fontStyle: FontStyle.italic,
                    fontSize: _fontSize.value - 4.0,
                    fontWeight: FontWeight.w500,
                  ),
              ),
            ),
          // Measures (chords row)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final blockWidth = (constraints.maxWidth - (8.0 * 4)) / 5;
                    return Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _buildMeasureCells(row.measures, colors, blockWidth),
                    );
                  },
                ),
              ),
              if (row.repetition != null && !hideRowRepetition) ...[
                const SizedBox(width: 12),
                Text(
                  row.repetition!,
                  style: TextStyle(
                    color: _getLyricColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: _fontSize.value + 2.0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMeasureCells(List<List<String>> measures, ColorScheme colors, double blockWidth) {
    List<Widget> cells = [];

    for (int i = 0; i < measures.length; i++) {
      final measureChords = measures[i];
      final transposedChords = measureChords
          .map((chord) => ChordTransposer.transpose(chord, _transposeSteps.value))
          .join('  ');

      cells.add(
        Container(
          width: blockWidth,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.outline.withOpacity(0.3)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              transposedChords,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: _fontSize.value - 6.0,
                fontWeight: FontWeight.bold,
                color: _getChordColor(),
              ),
            ),
          ),
        ),
      );
    }
    return cells;
  }

  Color _getSectionColor(String title) {
    final clean = title.toUpperCase();
    if (clean.contains('INTRO') || clean.contains('SOLO') || clean.contains('INSTRUMENTAL')) {
      return const Color(0xFF5B21B6); // Purple
    } else if (clean.contains('REFRÃO') || clean.contains('REFRAO') || clean.contains('CHORUS')) {
      return const Color(0xFF065F46); // Green
    } else if (clean.contains('PONTE') || clean.contains('BRIDGE')) {
      return const Color(0xFFC2410C); // Orange/Coral
    } else {
      return const Color(0xFF1E3A8A); // Dark Blue
    }
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

// ─────────────────────────────────────────────
//  Mini Audio Player Widget
// ─────────────────────────────────────────────
class _MiniAudioPlayer extends StatefulWidget {
  final String title;
  final String artist;
  final String videoId;
  final html.IFrameElement? iframeElement;
  final VoidCallback onExpand;

  const _MiniAudioPlayer({
    required this.title,
    required this.artist,
    required this.videoId,
    required this.iframeElement,
    required this.onExpand,
  });

  @override
  State<_MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<_MiniAudioPlayer> {
  bool _isPlaying = false;
  double _progress = 0.0;
  double _volume = 0.8;
  Timer? _progressTimer;
  double _pitchShift = 0.0;

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _sendCommand(String func, [String args = '']) {
    final argsJson = args.isEmpty ? '[]' : '[$args]';
    widget.iframeElement?.contentWindow?.postMessage(
      '{"event":"command","func":"$func","args":$argsJson}',
      '*',
    );
  }

  void _togglePlayPause() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _sendCommand('playVideo');
      _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _progress = (_progress + 0.003).clamp(0.0, 1.0));
      });
    } else {
      _sendCommand('pauseVideo');
      _progressTimer?.cancel();
    }
  }

  void _seek(double value) {
    setState(() => _progress = value);
    final seekSec = (value * 300).toInt();
    _sendCommand('seekTo', '$seekSec');
  }

  void _setVolume(double value) {
    setState(() => _volume = value);
    final vol = (value * 100).toInt();
    _sendCommand('setVolume', '$vol');
  }

  String get _timeDisplay {
    const total = 300;
    final current = (_progress * total).toInt();
    final m = current ~/ 60;
    final s = current % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = widget.videoId.isNotEmpty
        ? 'https://img.youtube.com/vi/${widget.videoId}/mqdefault.jpg'
        : null;

    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      color: colors.surfaceContainerHighest,
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outline.withOpacity(0.1)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: thumb + title + expand
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: thumbnail != null
                        ? Image.network(thumbnail, width: 44, height: 44, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ytIcon())
                        : _ytIcon(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                        Text(widget.artist,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_full, color: Colors.white38, size: 18),
                    tooltip: 'Abrir vídeo',
                    onPressed: widget.onExpand,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Progress bar + time
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: const Color(0xFF4EDE9C),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFF4EDE9C),
                      overlayColor: const Color(0x224EDE9C),
                    ),
                    child: Slider(value: _progress, onChanged: _seek),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_timeDisplay, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        const Text('5:00', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Controls: rewind / play-pause / forward
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white60, size: 22),
                    tooltip: 'Voltar 10s',
                    onPressed: () => _seek(((_progress * 300) - 10).clamp(0.0, 300.0) / 300),
                  ),
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4EDE9C), Color(0xFF22C55E)],
                        ),
                        boxShadow: [BoxShadow(color: const Color(0xFF4EDE9C).withOpacity(0.35), blurRadius: 10)],
                      ),
                      child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.black, size: 24),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: Colors.white60, size: 22),
                    tooltip: 'Avançar 10s',
                    onPressed: () => _seek(((_progress * 300) + 10).clamp(0.0, 300.0) / 300),
                  ),
                ],
              ),
            ),

            // Volume control
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  Icon(
                    _volume == 0 ? Icons.volume_off : _volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                    color: Colors.white38, size: 16,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: Colors.white54,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.white70,
                        overlayColor: Colors.white12,
                      ),
                      child: Slider(value: _volume, onChanged: _setVolume),
                    ),
                  ),
                ],
              ),
            ),

            // Voice modulator placeholder
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq, color: Color(0xFF818CF8), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Modulador de Voz',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              const Text('Tom: ', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              Text(
                                _pitchShift == 0
                                    ? 'Original'
                                    : (_pitchShift > 0 ? '+${_pitchShift.toStringAsFixed(0)}' : _pitchShift.toStringAsFixed(0)),
                                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          activeTrackColor: const Color(0xFF818CF8),
                          inactiveTrackColor: Colors.white10,
                          thumbColor: const Color(0xFF818CF8),
                          overlayColor: const Color(0x22818CF8),
                        ),
                        child: Slider(
                          value: _pitchShift,
                          min: -6,
                          max: 6,
                          divisions: 12,
                          onChanged: (v) => setState(() => _pitchShift = v),
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
    );
  }

  Widget _ytIcon() => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
  );
}
