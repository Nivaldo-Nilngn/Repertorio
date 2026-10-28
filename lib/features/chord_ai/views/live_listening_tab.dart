import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import '../services/audio_recording_service.dart';
import '../services/chord_repository.dart';
import '../services/youtube_service.dart';
import '../services/setlist_repository.dart';
import '../services/ai_chord_analysis_service.dart';
import '../widgets/guitar_fretboard.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/ukulele_fretboard.dart';
import '../widgets/scrolling_waveform_timeline.dart';
import '../widgets/chordify_beat_grid.dart';
import '../widgets/youtube_media_dock.dart';
import '../widgets/youtube_search_dialog.dart';
import '../services/chord_simplifier.dart';
import '../models/chord_data.dart';
import '../../songs/widgets/youtube_iframe_stub.dart'
    if (dart.library.html) '../../songs/widgets/youtube_iframe_web.dart'
    as yt_web;

enum HarmonicViewMode { diagram, notes, piano }
enum TimelineDisplayMode { chordifyGrid, chordAiWaveform, cifraLyrics }

class LiveListeningTab extends StatefulWidget {
  final AudioRecordingService audioService;
  final ChordRepository chordRepository;
  final FeaturedSong? initialSong;
  final VoidCallback? onBackToSearch;

  const LiveListeningTab({
    super.key,
    required this.audioService,
    required this.chordRepository,
    this.initialSong,
    this.onBackToSearch,
  });

  @override
  State<LiveListeningTab> createState() => LiveListeningTabState();
}

class LiveListeningTabState extends State<LiveListeningTab> {
  final YouTubeService _youtubeService = YouTubeService();
  final AiChordAnalysisService _aiService = AiChordAnalysisService();
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  String? _lastAudioSongId;
  StreamSubscription? _audioPosSub;
  StreamSubscription? _audioDurSub;
  StreamSubscription? _audioStateSub;

  YoutubePlayerController? _ytController;
  Timer? _desktopPlaybackTimer;

  // Motor de tempo linear contínuo (Stopwatch + 16ms Ticker)
  final Stopwatch _playbackStopwatch = Stopwatch();
  Duration _playbackOffset = Duration.zero;

  bool get isYoutubePlayerSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  late FeaturedSong _currentSong;
  FeaturedSong get currentSong => _currentSong;
  FeaturedSong? get initialSong => widget.initialSong;
  bool _isPlaying = false;
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  String _analysisStatus = '';
  String? _aiSummary;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 3, seconds: 45);
  double _playbackSpeed = 1.0;
  int _transposeSemitones = 0;
  int _capo = 0;
  ChordComplexity _chordComplexity = ChordComplexity.advanced;
  String _activeChord = '';
  TimelineDisplayMode _timelineMode = TimelineDisplayMode.chordifyGrid;
  HarmonicViewMode _harmonicViewMode = HarmonicViewMode.diagram;

  Timer? _positionPollingTimer;
  DateTime? _lastUserToggleTime;
  double _lastYtCurTime = -1.0;

  @override
  void initState() {
    super.initState();
    _currentSong = widget.initialSong ?? SetlistRepository.allSongs.first;
    _totalDuration = Duration(seconds: _currentSong.durationSeconds);
    _syncChordFromPosition(0.0);

    _initYoutubeController(_currentSong.id);

    _audioPlayer.setVolume(1.0);
    _audioStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      final playing = state == ap.PlayerState.playing;
      if (_isPlaying != playing) {
        setState(() => _isPlaying = playing);
      }
      if (playing) {
        _startPlaybackTimer();
      } else if (state == ap.PlayerState.paused ||
          state == ap.PlayerState.completed ||
          state == ap.PlayerState.stopped) {
        _desktopPlaybackTimer?.cancel();
        _playbackStopwatch.stop();
      }
    });

    _audioPosSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      if (_ytController == null || !isYoutubePlayerSupported) {
        final curSec = _currentPosition.inMilliseconds / 1000.0;
        final posSec = pos.inMilliseconds / 1000.0;
        if ((posSec - curSec).abs() > 1.0) {
          setState(() {
            _currentPosition = pos;
            _playbackOffset = pos;
            _playbackStopwatch.reset();
            if (_isPlaying) _playbackStopwatch.start();
            _syncChordFromPosition(posSec);
          });
        }
      }
    });

    _audioDurSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (!mounted) return;
      if (dur.inSeconds > 0 && dur.inSeconds != _totalDuration.inSeconds) {
        setState(() => _totalDuration = dur);
      }
    });

    // Se a música inicial ainda não possui análise de acordes por IA, inicia automaticamente
    if (_currentSong.measures.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentSong.measures.isEmpty && !_isAnalyzing) {
          _runAiAnalysis(targetSong: _currentSong);
        }
      });
    }
  }

  /// Ticker contínuo suave de 33ms (~30 FPS) usando clock de alta precisão
  void _startPlaybackTimer() {
    _desktopPlaybackTimer?.cancel();
    _playbackStopwatch.reset();
    _playbackStopwatch.start();
    _playbackOffset = _currentPosition;

    _desktopPlaybackTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (timer) {
        if (!mounted || !_isPlaying || _isAnalyzing) {
          timer.cancel();
          _playbackStopwatch.stop();
          return;
        }

        final elapsedMs =
            (_playbackStopwatch.elapsedMilliseconds * _playbackSpeed).toInt();
        final nextMs = _playbackOffset.inMilliseconds + elapsedMs;

        if (nextMs >= _totalDuration.inMilliseconds) {
          setState(() {
            _currentPosition = Duration.zero;
            _isPlaying = false;
            _playbackStopwatch.stop();
          });
          timer.cancel();
        } else {
          setState(() {
            _currentPosition = Duration(milliseconds: nextMs);
            _syncChordFromPosition(nextMs / 1000.0);
          });
        }
      },
    );
  }

  void _initYoutubeController(String videoId) {
    _positionPollingTimer?.cancel();
    _desktopPlaybackTimer?.cancel();
    _playbackStopwatch.stop();

    try {
      _ytController?.close();
    } catch (_) {}
    _ytController = null;

    if (kIsWeb) {
      yt_web.registerYoutubeIframe(videoId, videoId);
      if (_isPlaying) _startPlaybackTimer();
      return;
    }

    if (!isYoutubePlayerSupported) {
      if (_isPlaying) _startPlaybackTimer();
      return;
    }

    try {
      final controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
          enableCaption: false,
          showVideoAnnotations: false,
          loop: false,
        ),
      );
      _ytController = controller;

      _positionPollingTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) async {
          if (!mounted || _ytController == null || _isAnalyzing) return;
          try {
            final curTime = await controller.currentTime;
            final durTime = await controller.duration;
            final playerState = controller.value.playerState;

            if (mounted && !_isAnalyzing) {
              if (durTime > 0 && durTime.toInt() != _totalDuration.inSeconds) {
                setState(
                    () => _totalDuration = Duration(seconds: durTime.toInt()));
              }

              final isRecentlyToggled = _lastUserToggleTime != null &&
                  DateTime.now().difference(_lastUserToggleTime!) <
                      const Duration(milliseconds: 1500);

              if (playerState == PlayerState.playing && !_isPlaying) {
                setState(() => _isPlaying = true);
                _startPlaybackTimer();
              } else if (!isRecentlyToggled &&
                  (playerState == PlayerState.paused ||
                      playerState == PlayerState.ended) &&
                  _isPlaying) {
                setState(() => _isPlaying = false);
                _desktopPlaybackTimer?.cancel();
                _playbackStopwatch.stop();
              }

              final ytIsProgressing = playerState == PlayerState.playing &&
                  (curTime - _lastYtCurTime).abs() > 0.01;

              if (ytIsProgressing && curTime > 0.05) {
                _lastYtCurTime = curTime;
                final curSec = _currentPosition.inMilliseconds / 1000.0;
                final diff = (curTime - curSec).abs();
                if (diff > 0.45) {
                  setState(() {
                    _currentPosition =
                        Duration(milliseconds: (curTime * 1000).toInt());
                    _playbackOffset = _currentPosition;
                    _playbackStopwatch.reset();
                    if (_isPlaying) _playbackStopwatch.start();
                    _syncChordFromPosition(curTime);
                  });
                }
              }
            }
          } catch (_) {}
        },
      );
    } catch (e) {
      debugPrint('Aviso: Player YouTube não inicializado ($e). Modo áudio sincronizado ativo.');
      _ytController = null;
      if (_isPlaying) _startPlaybackTimer();
    }
  }

  /// Método público para carregar qualquer música de setlist ou YouTube
  void loadSong(FeaturedSong song, {bool triggerAnalysis = false}) {
    final sameVideo =
        song.id == _currentSong.id && (_ytController != null || kIsWeb);

    setState(() {
      _currentSong = song;
      _totalDuration = Duration(seconds: song.durationSeconds);
      if (!sameVideo) {
        _currentPosition = Duration.zero;
        _playbackOffset = Duration.zero;
        _playbackStopwatch.reset();
        _lastAudioSongId = null;
        try {
          _audioPlayer.stop();
        } catch (_) {}
      }
      _transposeSemitones = 0;
      _syncChordFromPosition(_currentPosition.inMilliseconds / 1000.0);
    });

    if (!sameVideo) _initYoutubeController(song.id);
    if (triggerAnalysis) _runAiAnalysis(targetSong: song);
  }

  /// Executa o pipeline de análise harmônica com áudio do vídeo
  Future<void> _runAiAnalysis({FeaturedSong? targetSong}) async {
    final songToAnalyze = targetSong ?? _currentSong;

    _desktopPlaybackTimer?.cancel();
    _playbackStopwatch.stop();
    try {
      _ytController?.pauseVideo();
    } catch (_) {}
    try {
      _audioPlayer.pause();
    } catch (_) {}

    setState(() {
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _playbackOffset = Duration.zero;
      _playbackStopwatch.reset();
      _syncChordFromPosition(0.0);
      _isAnalyzing = true;
      _analysisProgress = 0.05;
      _analysisStatus = 'Iniciando análise do áudio...';
    });

    try {
      final result = await _aiService.analyzeSong(
        title: songToAnalyze.title,
        artist: songToAnalyze.artist,
        videoId: songToAnalyze.id,
        durationSeconds: songToAnalyze.durationSeconds,
        referenceBpm: songToAnalyze.bpm > 0 ? songToAnalyze.bpm : null,
        referenceKey: songToAnalyze.key.isNotEmpty ? songToAnalyze.key : null,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _analysisProgress = prog;
              _analysisStatus = status;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _aiSummary = result.summary;
        _currentPosition = Duration.zero;
      });
      loadSong(result.song);
      _seekTo(Duration.zero);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF141A28),
        content: Text('✨ ${result.summary}',
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF3B1218),
        content: Text('Não foi possível ler os acordes: $e',
            style: const TextStyle(color: Colors.white)),
        action: SnackBarAction(
          label: 'Tentar de novo',
          textColor: const Color(0xFF00E5FF),
          onPressed: () => _runAiAnalysis(targetSong: songToAnalyze),
        ),
        duration: const Duration(seconds: 8),
      ));
    }
  }

  void _syncChordFromPosition(double seconds) {
    if (_currentSong.measures.isNotEmpty) {
      for (final m in _currentSong.measures) {
        if (seconds >= m.startSeconds &&
            seconds < m.startSeconds + m.durationSeconds) {
          if (_activeChord != m.chord) {
            _activeChord = m.chord;
          }
          return;
        }
      }
    }

    final markers = _currentSong.chordMarkers;
    if (markers.isEmpty) {
      if (_activeChord.isNotEmpty) {
        setState(() => _activeChord = '');
      }
      return;
    }

    var lo = 0, hi = markers.length - 1, idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (markers[mid].second <= seconds) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    _activeChord = markers[idx].chord;
  }

  String get _displayActiveChord {
    if (_activeChord.isEmpty) return '';
    final transposed = SetlistRepository.transposeChord(
      _activeChord,
      _transposeSemitones,
    );
    return ChordSimplifier.simplify(transposed, _chordComplexity);
  }

  /// Acorde diferente imediatamente anterior
  String? get previousChord {
    if (_currentSong.measures.isEmpty) return null;
    final currentSec = _currentPosition.inMilliseconds / 1000.0;
    String? prev;
    for (final m in _currentSong.measures) {
      if (m.startSeconds + m.durationSeconds <= currentSec) {
        if (m.chord != _activeChord) {
          prev = m.chord;
        }
      } else {
        break;
      }
    }
    if (prev != null) {
      final t = SetlistRepository.transposeChord(prev, _transposeSemitones);
      return ChordSimplifier.simplify(t, _chordComplexity);
    }
    return null;
  }

  /// Próximo acorde diferente subsequente
  String? get nextChord {
    if (_currentSong.measures.isEmpty) return null;
    final currentSec = _currentPosition.inMilliseconds / 1000.0;
    for (final m in _currentSong.measures) {
      if (m.startSeconds > currentSec && m.chord != _activeChord) {
        final t = SetlistRepository.transposeChord(m.chord, _transposeSemitones);
        return ChordSimplifier.simplify(t, _chordComplexity);
      }
    }
    return null;
  }

  /// Lista dos próximos 4 acordes únicos da progressão (estilo Chorda)
  List<String> get upcomingChords {
    if (_currentSong.measures.isEmpty) return [];
    final currentSec = _currentPosition.inMilliseconds / 1000.0;
    final list = <String>[];
    String last = _activeChord;
    for (final m in _currentSong.measures) {
      if (m.startSeconds > currentSec) {
        if (m.chord != last && !list.contains(m.chord)) {
          final t = SetlistRepository.transposeChord(m.chord, _transposeSemitones);
          final sim = ChordSimplifier.simplify(t, _chordComplexity);
          if (!list.contains(sim)) {
            list.add(sim);
          }
          last = m.chord;
          if (list.length >= 4) break;
        }
      }
    }
    return list;
  }

  Future<void> _togglePlay() async {
    final nextPlaying = !_isPlaying;
    _lastUserToggleTime = DateTime.now();

    if (_ytController != null && isYoutubePlayerSupported) {
      try {
        if (nextPlaying) {
          _ytController!.playVideo();
        } else {
          _ytController!.pauseVideo();
        }
      } catch (_) {}
    } else {
      try {
        if (nextPlaying) {
          final audioUrl = 'http://localhost:8000/audio/${_currentSong.id}';
          if (_audioPlayer.state == ap.PlayerState.paused &&
              _lastAudioSongId == _currentSong.id) {
            await _audioPlayer.resume();
          } else {
            _lastAudioSongId = _currentSong.id;
            await _audioPlayer.play(
              ap.UrlSource(audioUrl),
              position: _currentPosition,
            );
          }
          await _audioPlayer.setPlaybackRate(_playbackSpeed);
        } else {
          await _audioPlayer.pause();
        }
      } catch (e) {
        debugPrint('Aviso ao controlar streaming de áudio nativo: $e');
      }
    }

    setState(() => _isPlaying = nextPlaying);

    if (nextPlaying) {
      _startPlaybackTimer();
    } else {
      _desktopPlaybackTimer?.cancel();
      _playbackStopwatch.stop();
    }
  }

  void _seekTo(Duration dur) {
    if (_ytController != null && isYoutubePlayerSupported) {
      try {
        _ytController!.seekTo(
          seconds: dur.inMilliseconds / 1000.0,
          allowSeekAhead: true,
        );
      } catch (_) {}
    } else {
      try {
        _audioPlayer.seek(dur);
      } catch (_) {}
    }

    _playbackStopwatch.reset();
    if (_isPlaying) _playbackStopwatch.start();
    _playbackOffset = dur;

    setState(() {
      _currentPosition = dur;
      _syncChordFromPosition(dur.inMilliseconds / 1000.0);
    });
  }

  void _openYouTubeSearch() async {
    final selectedVideo = await showDialog<YouTubeVideoItem>(
      context: context,
      builder: (context) => YouTubeSearchDialog(
        youtubeService: _youtubeService,
        initialQuery: _currentSong.title.isNotEmpty
            ? '${_currentSong.artist} ${_currentSong.title}'
            : '',
      ),
    );

    if (selectedVideo != null) {
      final generatedSong = SetlistRepository.findOrGenerateSongForVideo(
        id: selectedVideo.id,
        title: selectedVideo.title,
        artist: selectedVideo.author,
        durationSeconds: _currentSong.durationSeconds,
      );
      loadSong(generatedSong, triggerAnalysis: true);
    }
  }

  void _openCifraClubImportDialog() {
    final queryController = TextEditingController(
      text: '${_currentSong.artist} ${_currentSong.title}'.trim(),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: Color(0xFF00E5FF)),
            SizedBox(width: 10),
            Text('Buscar Cifra Club',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Importe a cifra real oficial do Cifra Club para sincronizar com esta música:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: queryController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1F30),
                hintText: 'Nome da música ou artista...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _importFromCifraClub(queryController.text.trim());
            },
            child: const Text('Buscar e Importar'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromCifraClub(String query) async {
    if (query.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF141724),
      content: Text('Buscando "$query" no Cifra Club...',
          style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 2),
    ));
    _runAiAnalysis(targetSong: _currentSong);
  }

  Widget _buildAiAnalysisOverlay() {
    return Container(
      color: const Color(0xFF0A0D14).withValues(alpha: 0.94),
      child: Center(
        child: Container(
          width: 500,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF2F6BFF).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F6BFF).withValues(alpha: 0.2),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF2F6BFF), Color(0xFF00D2FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F6BFF).withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'CHORD AI • ANÁLISE HARMÔNICA EM TEMPO REAL',
                style: TextStyle(
                  color: Color(0xFF00D2FF),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentSong.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currentSong.artist,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _analysisProgress > 0 ? _analysisProgress : null,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2F6BFF)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _analysisStatus.isNotEmpty
                          ? _analysisStatus
                          : 'Processando áudio com IA...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(_analysisProgress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Color(0xFF00D2FF),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  setState(() => _isAnalyzing = false);
                },
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: Colors.white54),
                label: const Text(
                  'Continuar em segundo plano',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionPollingTimer?.cancel();
    _desktopPlaybackTimer?.cancel();
    _playbackStopwatch.stop();
    _audioPosSub?.cancel();
    _audioDurSub?.cancel();
    _audioStateSub?.cancel();
    try {
      _audioPlayer.dispose();
    } catch (_) {}
    try {
      _ytController?.close();
    } catch (_) {}
    _youtubeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chordInfo = widget.chordRepository.getChord(_displayActiveChord);
    final prevChordName = previousChord;
    final nextChordName = nextChord;
    final prevChordInfo = prevChordName != null
        ? widget.chordRepository.getChord(prevChordName)
        : null;
    final nextChordInfo = nextChordName != null
        ? widget.chordRepository.getChord(nextChordName)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E1C),
          body: Stack(
            children: [
              Column(
                children: [
                  // 1. Barra Superior Chorda (Voltar + Título + Ações)
                  _buildChordaTopHeader(),

                  // 2. Área Central sem Rolagem (Cards Superiores + Instrumentos + Timeline 100% visíveis)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Barra de Resumo de Acordes e Informações Musicais
                          _buildChordaHeroCards(isWide),

                          const SizedBox(height: 6),

                          // Barra Unificada de Controles (Visualização Harmônica + Linha do Tempo)
                          _buildCombinedControlBar(),

                          const SizedBox(height: 6),

                          // Área Central de Instrumentos (ajusta-se dinamicamente ao espaço)
                          Expanded(
                            child: Center(
                              child: _buildInstrumentArea(
                                chordInfo: chordInfo,
                                prevChordInfo: prevChordInfo,
                                nextChordInfo: nextChordInfo,
                                prevName: prevChordName,
                                nextName: nextChordName,
                                isWide: isWide,
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Linha do Tempo / Beat Grid no estilo Chorda
                          _buildTimelineSection(),
                        ],
                      ),
                    ),
                  ),

                  // 3. YouTube Media Dock Acoplado na Base
                  YouTubeMediaDock(
                    currentVideo: YouTubeVideoItem(
                      id: _currentSong.id,
                      title: _currentSong.title,
                      author: _currentSong.artist,
                      duration: _currentSong.formattedDuration,
                      thumbnailUrl: _currentSong.thumbnailUrl,
                    ),
                    isPlaying: _isPlaying,
                    currentPosition: _currentPosition,
                    totalDuration: _totalDuration,
                    playbackSpeed: _playbackSpeed,
                    pitchSemitones: _transposeSemitones,
                    videoPlayer: _buildMiniVideoPlayer(),
                    onSelectMedia: _openYouTubeSearch,
                    onTogglePlay: _togglePlay,
                    onRewind: () {
                      final target =
                          _currentPosition - const Duration(seconds: 5);
                      _seekTo(target < Duration.zero ? Duration.zero : target);
                    },
                    onForward: () {
                      final target =
                          _currentPosition + const Duration(seconds: 5);
                      _seekTo(target);
                    },
                    onSeek: (dur) => _seekTo(dur),
                    onSpeedChanged: (speed) {
                      setState(() => _playbackSpeed = speed);
                      _ytController?.setPlaybackRate(speed);
                      try {
                        _audioPlayer.setPlaybackRate(speed);
                      } catch (_) {}
                    },
                    onPitchChanged: (pitch) {
                      setState(() => _transposeSemitones = pitch);
                    },
                  ),
                ],
              ),
              if (_isAnalyzing)
                Positioned.fill(
                  child: _buildAiAnalysisOverlay(),
                ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // 1. Barra Superior Chorda (Voltar + Título + Ações)
  // -------------------------------------------------------------------------
  Widget _buildChordaTopHeader() {
    return Container(
      color: const Color(0xFF0F1224),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Botão Voltar para a Tela de Busca
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Voltar para a Busca',
            onPressed: () {
              if (widget.onBackToSearch != null) {
                widget.onBackToSearch!();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          const SizedBox(width: 8),

          // Título da Música em destaque
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSong.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  _currentSong.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Botão Analisar IA
          InkWell(
            onTap: () => _runAiAnalysis(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2F6BFF), Color(0xFF00D2FF)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Analisar IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botão Cifra Club
          IconButton(
            tooltip: 'Buscar no Cifra Club',
            icon: const Icon(Icons.description_outlined,
                color: Color(0xFF00D2FF), size: 20),
            onPressed: _openCifraClubImportDialog,
          ),

          // Botão Buscar outra música
          IconButton(
            tooltip: 'Buscar no YouTube',
            icon: const Icon(Icons.search_rounded,
                color: Colors.white70, size: 22),
            onPressed: _openYouTubeSearch,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 2. Dois Cards Superiores no Estilo Chorda (Imagem 2)
  // -------------------------------------------------------------------------
  // -------------------------------------------------------------------------
  // 2. Barra de Resumo Compacta (Acorde Atual + Próximos + Infos Musicais)
  // -------------------------------------------------------------------------
  Widget _buildChordaHeroCards(bool isWide) {
    final activeDisplay =
        _displayActiveChord.isNotEmpty ? _displayActiveChord : '--';
    final upcoming = upcomingChords;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF13172C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Acorde Atual
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ACORDE ATUAL:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                activeDisplay,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00E5FF),
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: Color(0xFF2F6BFF),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 22,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 14),

          // Próximos Acordes
          Expanded(
            child: Row(
              children: [
                const Text(
                  'PRÓXIMOS:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(width: 8),
                if (upcoming.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final chord in upcoming)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A213D),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF2F6BFF)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                chord,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00D2FF),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    'Aguardando progressão...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Informações Musicais
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoBadge('Tom',
                  _currentSong.key.isNotEmpty ? _currentSong.key : 'C'),
              const SizedBox(width: 6),
              _buildInfoBadge('BPM', '${_currentSong.bpm}'),
              const SizedBox(width: 6),
              _buildInfoBadge('Compasso', '4/4'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A213D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 3. Barra Unificada de Controles (Visualização Harmônica + Linha do Tempo)
  // -------------------------------------------------------------------------
  Widget _buildCombinedControlBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Seletor de Visualização Harmônica
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Visualização:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF13172C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHarmonicToggleItem(
                    label: 'Diagrama',
                    icon: Icons.grid_on_rounded,
                    mode: HarmonicViewMode.diagram,
                  ),
                  _buildHarmonicToggleItem(
                    label: 'Notas',
                    icon: Icons.music_note_rounded,
                    mode: HarmonicViewMode.notes,
                  ),
                  _buildHarmonicToggleItem(
                    label: 'Teclado',
                    icon: Icons.piano_rounded,
                    mode: HarmonicViewMode.piano,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Seletor de Modo da Linha do Tempo
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Linha do tempo:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF13172C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimelineToggleItem(
                    label: 'Compassos',
                    icon: Icons.view_column_rounded,
                    mode: TimelineDisplayMode.chordifyGrid,
                  ),
                  _buildTimelineToggleItem(
                    label: 'Forma de onda',
                    icon: Icons.graphic_eq_rounded,
                    mode: TimelineDisplayMode.chordAiWaveform,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHarmonicToggleItem({
    required String label,
    required IconData icon,
    required HarmonicViewMode mode,
  }) {
    final isSelected = _harmonicViewMode == mode;
    return InkWell(
      onTap: () => setState(() => _harmonicViewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2F6BFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineToggleItem({
    required String label,
    required IconData icon,
    required TimelineDisplayMode mode,
  }) {
    final isSelected = _timelineMode == mode;
    return InkWell(
      onTap: () => setState(() => _timelineMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2F6BFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 4. Área Central dos Instrumentos (Ajuste Dinâmico sem Scroll)
  // -------------------------------------------------------------------------
  Widget _buildInstrumentArea({
    required ChordInfo chordInfo,
    required ChordInfo? prevChordInfo,
    required ChordInfo? nextChordInfo,
    required String? prevName,
    required String? nextName,
    required bool isWide,
  }) {
    switch (_harmonicViewMode) {
      case HarmonicViewMode.diagram:
        return LayoutBuilder(
          builder: (context, box) {
            final availHeight =
                box.maxHeight.isFinite ? box.maxHeight : 180.0;
            final centerHeight = (availHeight - 26).clamp(115.0, 185.0);
            final centerWidth = (centerHeight * 0.82).clamp(95.0, 150.0);
            final sideHeight = centerHeight * 0.78;
            final sideWidth = centerWidth * 0.78;

            return Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Acorde Anterior (menor, à esquerda)
                  if (prevChordInfo != null && prevName != null)
                    Opacity(
                      opacity: 0.45,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            prevName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          GuitarFretboardWidget(
                            position: prevChordInfo.guitarPosition ??
                                const GuitarPosition(
                                    frets: [-1, -1, -1, -1, -1, -1]),
                            width: sideWidth,
                            height: sideHeight,
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(width: sideWidth),

                  const SizedBox(width: 18),

                  // Acorde Atual em Destaque Central
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayActiveChord.isNotEmpty
                            ? _displayActiveChord
                            : '--',
                        style: const TextStyle(
                          color: Color(0xFF00D2FF),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Color(0xFF2F6BFF),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      GuitarFretboardWidget(
                        position: chordInfo.guitarPosition ??
                            const GuitarPosition(frets: [0, 0, 0, 0, 0, 0]),
                        width: centerWidth,
                        height: centerHeight,
                      ),
                    ],
                  ),

                  const SizedBox(width: 18),

                  // Próximo Acorde (menor, à direita)
                  if (nextChordInfo != null && nextName != null)
                    Opacity(
                      opacity: 0.65,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nextName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          GuitarFretboardWidget(
                            position: nextChordInfo.guitarPosition ??
                                const GuitarPosition(
                                    frets: [-1, -1, -1, -1, -1, -1]),
                            width: sideWidth,
                            height: sideHeight,
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(width: sideWidth),
                ],
              ),
            );
          },
        );

      case HarmonicViewMode.notes:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final n in chordInfo.notes)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E284A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2F6BFF)),
                      ),
                      child: Text(
                        n,
                        style: const TextStyle(
                          color: Color(0xFF00D2FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              PianoKeyboardWidget(
                activeNotes: chordInfo.notes,
                width: isWide ? 440 : 320,
                height: 130,
              ),
            ],
          ),
        );

      case HarmonicViewMode.piano:
        return Center(
          child: PianoKeyboardWidget(
            activeNotes: chordInfo.notes,
            width: isWide ? 500 : 340,
            height: 150,
          ),
        );
    }
  }

  // -------------------------------------------------------------------------
  // 5. Linha do Tempo / Beat Grid no Estilo Chorda
  // -------------------------------------------------------------------------
  Widget _buildTimelineSection() {
    final currentSec = _currentPosition.inMilliseconds / 1000.0;

    if (_currentSong.measures.isEmpty) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF13172C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF2F6BFF).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF00D2FF), size: 18),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Clique em "Analisar IA" para sincronizar compassos e cifras.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : () => _runAiAnalysis(),
              icon: const Icon(Icons.auto_awesome, size: 14),
              label: const Text('Analisar IA', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F6BFF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
      );
    }

    if (_timelineMode == TimelineDisplayMode.chordifyGrid) {
      return ChordifyBeatGrid(
        measures: _currentSong.measures,
        currentSeconds: currentSec,
        transposeSemitones: _transposeSemitones,
        complexity: _chordComplexity,
        onSeek: (sec) => _seekTo(Duration(milliseconds: (sec * 1000).round())),
      );
    } else {
      return ScrollingWaveformTimeline(
        currentSeconds: currentSec,
        totalSeconds: _totalDuration.inMilliseconds / 1000.0,
        chordMarkers: _currentSong.chordMarkers,
        keySignature: _currentSong.key,
        bpm: _currentSong.bpm,
        onSeek: (sec) => _seekTo(Duration(milliseconds: (sec * 1000).round())),
      );
    }
  }

  Widget? _buildMiniVideoPlayer() {
    if (kIsWeb) {
      yt_web.registerYoutubeIframe(_currentSong.id, _currentSong.id);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: yt_web.buildYoutubeView(_currentSong.id),
      );
    }
    if (_ytController != null && isYoutubePlayerSupported) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: YoutubePlayer(
          key: ValueKey(_currentSong.id),
          controller: _ytController!,
          aspectRatio: 16 / 9,
        ),
      );
    }
    return null;
  }
}
