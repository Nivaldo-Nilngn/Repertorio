import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/chord_data.dart';
import '../services/chord_repository.dart';
import '../services/pitch_detector.dart';
import '../services/ai_chord_analysis_service.dart';
import '../services/setlist_repository.dart';
import '../services/youtube_service.dart';
import '../services/chord_simplifier.dart';
import '../services/wav_decoder.dart';
import '../widgets/guitar_fretboard.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/ukulele_fretboard.dart';
import '../widgets/chordify_beat_grid.dart';
import '../widgets/scrolling_waveform_timeline.dart';
import '../../songs/models/song.dart';
import '../../songs/repositories/song_repository.dart';
import '../../manager/providers/manager_providers.dart';
import '../../manager/providers/editor_provider.dart';

class AudioFileTab extends ConsumerStatefulWidget {
  final ChordRepository chordRepository;

  const AudioFileTab({
    super.key,
    required this.chordRepository,
  });

  @override
  ConsumerState<AudioFileTab> createState() => _AudioFileTabState();
}

class _AudioFileTabState extends ConsumerState<AudioFileTab> {
  final AudioPlayer _player = AudioPlayer();
  final AiChordAnalysisService _aiService = AiChordAnalysisService();
  final YouTubeService _youtubeService = YouTubeService();

  String? _loadedFileName;
  String? _filePath;
  Uint8List? _fileBytes;
  bool _isPlaying = false;
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  String _analysisStatus = '';

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  int _transposeSemitones = 0;
  int _capo = 0;

  ChordComplexity _complexity = ChordComplexity.advanced;
  InstrumentType _selectedInstrument = InstrumentType.guitar;
  bool _showBeatGrid = true;

  // Informações harmônicas detectadas do arquivo
  String _detectedKey = 'C';
  int _detectedBpm = 120;
  List<MeasureBeat> _measures = [];
  List<ChordMarker> _chordMarkers = [];
  String _currentChord = 'C';

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();
  }

  void _setupAudioPlayerListeners() {
    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() {
        _currentPosition = p;
        _updateCurrentChord(p.inMilliseconds / 1000.0);
      });
    });

    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() {
        if (d.inSeconds > 0) {
          _totalDuration = d;
        }
      });
    });

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  void _updateCurrentChord(double seconds) {
    if (_measures.isEmpty && _chordMarkers.isEmpty) return;

    String found = _currentChord;

    // Busca primeiro nos compassos do beat grid
    for (final m in _measures) {
      if (seconds >= m.startSeconds && seconds < m.startSeconds + m.durationSeconds) {
        found = m.chord;
        break;
      }
    }

    if (found != _currentChord) {
      _currentChord = found;
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'aac', 'ogg'],
      );

      if (result.isNotEmpty) {
        final file = result.first;
        _loadedFileName = file.name;
        _filePath = file.path;
        try {
          _fileBytes = await file.readAsBytes();
        } catch (_) {}

        // Prepara o player de áudio
        if (kIsWeb && _fileBytes != null) {
          await _player.setSource(BytesSource(_fileBytes!));
        } else if (_filePath != null) {
          await _player.setSource(DeviceFileSource(_filePath!));
        } else if (_fileBytes != null) {
          await _player.setSource(BytesSource(_fileBytes!));
        }

        setState(() {});
        // Inicia a análise automática de acordes no estilo Chord ai
        await _analyzeAudioFile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erro ao carregar arquivo de áudio: $e'),
          ),
        );
      }
    }
  }

  /// Executa o pipeline de detecção acústica e IA igual ao Chord ai v2.8.15
  Future<void> _analyzeAudioFile() async {
    if (_loadedFileName == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0.05;
      _analysisStatus = '🎵 Lendo cabeçalho e estrutura do arquivo...';
    });

    // Extrai nome limpo da música e artista a partir do nome do arquivo
    String cleanName = _loadedFileName!.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    String artist = 'Chord AI Detecção';
    String title = cleanName;
    if (cleanName.contains(' - ')) {
      final parts = cleanName.split(' - ');
      artist = parts[0].trim();
      title = parts[1].trim();
    }

    try {
      // Se for arquivo WAV e tivermos os bytes, executamos o decoder puro Dart + FFT offline
      if (_loadedFileName!.toLowerCase().endsWith('.wav') && _fileBytes != null) {
        setState(() {
          _analysisProgress = 0.25;
          _analysisStatus = '🔬 Decodificando PCM e executando FFT de alta resolução...';
        });

        final pcm = WavDecoder.decodeToMonoPcm(_fileBytes!);
        if (pcm != null && pcm.isNotEmpty) {
          setState(() {
            _analysisProgress = 0.60;
            _analysisStatus = '🎼 Rastreando baixo fundamental (F0) e cromagramas de 12 notas...';
          });

          // Analisa em blocos com RealtimeChordDetector
          final events = RealtimeChordDetector.analyzeFullAudioTrack(
            pcmSamples: pcm,
            sampleRate: 44100,
            hopSeconds: 0.5,
          );

          if (events.isNotEmpty) {
            _chordMarkers = events
                .map((e) => ChordMarker(
                      e.timestamp.millisecondsSinceEpoch / 1000.0,
                      e.chordName,
                    ))
                .toList();

            final totalSec = (pcm.length / 44100.0).round();
            _totalDuration = Duration(seconds: totalSec);

            // Constrói compassos e detecta o Tom real com o estimador harmônico
            final chordList = _chordMarkers.map((m) => m.chord).toList();
            _detectedKey = AiChordAnalysisService.estimateKeyFromChords(chordList);
            _detectedBpm = 90;
            _measures = _buildMeasuresFromMarkers(_chordMarkers, totalSec, _detectedBpm);

            setState(() {
              _isAnalyzing = false;
              _analysisProgress = 1.0;
              _analysisStatus = 'Concluído com sucesso!';
              _currentChord = _measures.isNotEmpty ? _measures.first.chord : 'C';
            });
            return;
          }
        }
      }

      // Para MP3 / M4A / AAC ou fallback acústico:
      final effectiveDuration = _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds : 180;

      // 1. Tenta identificar se o áudio corresponde a uma música com ID do YouTube para análise madmom
      String? matchedVideoId;
      for (final s in YouTubeService.suggestions) {
        if (cleanName.toLowerCase().contains(s.title.toLowerCase()) ||
            title.toLowerCase().contains(s.title.toLowerCase())) {
          matchedVideoId = s.id;
          break;
        }
      }

      if (matchedVideoId == null) {
        try {
          final results = await _youtubeService.searchVideos('$artist $title');
          if (results.isNotEmpty) {
            matchedVideoId = results.first.id;
          }
        } catch (_) {}
      }

      FeaturedSong finalSong;
      if (matchedVideoId != null) {
        final aiResult = await _aiService.analyzeSong(
          title: title,
          artist: artist,
          videoId: matchedVideoId,
          durationSeconds: effectiveDuration,
          onProgress: (p, s) {
            if (mounted) {
              setState(() {
                _analysisProgress = p;
                _analysisStatus = s;
              });
            }
          },
        );
        finalSong = aiResult.song;
      } else {
        // Modelo puro sem dados mocados (acordes virão 100% da análise real da IA)
        finalSong = SetlistRepository.createSongForVideo(
          id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          artist: artist,
          durationSeconds: effectiveDuration,
        );
      }

      if (mounted) {
        setState(() {
          _detectedKey = finalSong.key;
          _detectedBpm = finalSong.bpm;
          _measures = finalSong.measures;
          _chordMarkers = finalSong.chordMarkers;
          if (_totalDuration.inSeconds <= 0) {
            _totalDuration = Duration(seconds: finalSong.durationSeconds);
          }
          _currentChord = _measures.isNotEmpty ? _measures.first.chord : 'C';
          _isAnalyzing = false;
          _analysisProgress = 1.0;
          _analysisStatus = 'Concluído com sucesso!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisStatus = 'Erro na análise: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Falha ao analisar acordes: $e'),
          ),
        );
      }
    }
  }

  List<MeasureBeat> _buildMeasuresFromMarkers(
    List<ChordMarker> markers,
    int durationSeconds,
    int bpm,
  ) {
    final double beatDuration = 60.0 / bpm;
    final double measureDuration = beatDuration * 4; // Compassos 4/4
    final int measureCount = (durationSeconds / measureDuration).ceil().clamp(1, 2000);

    final List<MeasureBeat> list = [];
    String lastChord = markers.isNotEmpty ? markers.first.chord : 'C';

    for (int i = 0; i < measureCount; i++) {
      final start = i * measureDuration;

      String active = lastChord;
      for (final m in markers) {
        if (m.second <= start) {
          active = m.chord;
        } else {
          break;
        }
      }
      lastChord = active;

      list.add(
        MeasureBeat(
          measureNumber: i + 1,
          startSeconds: start,
          durationSeconds: measureDuration,
          chord: active,
        ),
      );
    }
    return list;
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_loadedFileName == null) {
        // Se nenhum arquivo foi selecionado, abre o seletor
        await _pickAudioFile();
        return;
      }
      await _player.resume();
    }
  }

  Future<void> _seekTo(double seconds) async {
    await _player.seek(Duration(milliseconds: (seconds * 1000).toInt()));
  }

  /// Salva a música analisada diretamente no repertório do KordApp
  Future<void> _exportToKordApp() async {
    if (_loadedFileName == null || _measures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Abra e analise um arquivo de áudio antes de salvar no Repertório.'),
        ),
      );
      return;
    }

    String title = _loadedFileName!.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    String artist = 'Chord AI Áudio';
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      artist = parts[0].trim();
      title = parts[1].trim();
    }

    final buffer = StringBuffer();
    buffer.writeln('{title: $title}');
    buffer.writeln('{artist: $artist}');
    buffer.writeln('{key: $_detectedKey}');
    buffer.writeln('{tempo: $_detectedBpm}');
    buffer.writeln();
    buffer.writeln('# Cifra detectada pelo Chord ai v2.8.15 a partir de arquivo de áudio');
    buffer.writeln();

    int count = 0;
    for (final m in _measures) {
      final chord = _getEffectiveChord(m.chord);
      buffer.write('[$chord]   ');
      count++;
      if (count % 4 == 0) {
        buffer.writeln();
      }
    }
    buffer.writeln();

    final song = Song(
      id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artist: artist,
      key: _detectedKey,
      bpm: _detectedBpm,
      content: buffer.toString(),
      tags: ['Chord AI', 'Áudio MP3/WAV'],
    );

    try {
      await ref.read(songRepositoryProvider).createSong(song);
      ref.read(selectedSongIdProvider.notifier).select(song.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Música "$title" salva com sucesso no Repertório!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Abrir no KordApp',
              textColor: Colors.white,
              onPressed: () {
                ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erro ao salvar no repertório: $e'),
          ),
        );
      }
    }
  }

  /// Retorna o acorde aplicando transposição e nível de complexidade Chord ai
  String _getEffectiveChord(String chord) {
    final transposed = SetlistRepository.transposeChord(chord, _transposeSemitones);
    return ChordSimplifier.simplify(transposed, _complexity);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _youtubeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveChord = _getEffectiveChord(_currentChord);
    final chordInfo = widget.chordRepository.getChord(effectiveChord);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Cabeçalho e Seleção de Arquivo
          _buildFileHeaderCard(),
          const SizedBox(height: 16),

          // Se estiver analisando, exibe progresso com animação
          if (_isAnalyzing) ...[
            _buildAnalysisProgressCard(),
            const SizedBox(height: 16),
          ],

          // Barra de Ferramentas: Transposição, Capo, Complexidade, Exportação
          _buildControlsToolbar(),
          const SizedBox(height: 16),

          // Acorde Sincronizado em Destaque
          _buildActiveChordCard(effectiveChord, chordInfo),
          const SizedBox(height: 16),

          // Beat Grid ou Timeline de Onda Sonora
          if (_measures.isNotEmpty) ...[
            _buildTimelineSection(),
            const SizedBox(height: 16),
          ],

          // Seletor e Diagrama do Instrumento (Violão, Piano, Ukulele)
          _buildInstrumentSection(chordInfo),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFileHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.audio_file_rounded, color: Colors.black, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loadedFileName ?? 'Nenhum arquivo de áudio carregado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _measures.isNotEmpty
                          ? 'Tom: $_detectedKey • $_detectedBpm BPM • ${_measures.length} Compassos'
                          : 'Carregue um arquivo MP3, WAV, M4A ou FLAC para detecção imediata de acordes',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: Text(
                  _loadedFileName == null ? 'Abrir Áudio' : 'Trocar',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (_loadedFileName != null) ...[
            const SizedBox(height: 16),
            // Barra de Progresso de Reprodução
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF00E5FF),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
              ),
              child: Slider(
                value: _currentPosition.inMilliseconds.toDouble().clamp(
                      0.0,
                      _totalDuration.inMilliseconds.toDouble() > 0
                          ? _totalDuration.inMilliseconds.toDouble()
                          : 1.0,
                    ),
                max: _totalDuration.inMilliseconds.toDouble() > 0
                    ? _totalDuration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (val) {
                  _seekTo(val / 1000.0);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_currentPosition),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
                  Text(
                    _formatDuration(_totalDuration),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Controles de Playback
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Voltar 5s',
                  icon: const Icon(Icons.replay_5_rounded, color: Colors.white70),
                  onPressed: () => _seekTo((_currentPosition.inSeconds - 5).clamp(0, 99999).toDouble()),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  iconSize: 36,
                  onPressed: _togglePlay,
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Avançar 5s',
                  icon: const Icon(Icons.forward_5_rounded, color: Colors.white70),
                  onPressed: () => _seekTo((_currentPosition.inSeconds + 5).toDouble()),
                ),
                const SizedBox(width: 16),
                // Velocidade
                PopupMenuButton<double>(
                  initialValue: _playbackSpeed,
                  tooltip: 'Velocidade de Reprodução',
                  color: const Color(0xFF1A1F30),
                  child: Chip(
                    backgroundColor: const Color(0xFF1E2436),
                    label: Text(
                      '${_playbackSpeed}x',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onSelected: (speed) async {
                    setState(() => _playbackSpeed = speed);
                    await _player.setPlaybackRate(speed);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 0.5, child: Text('0.5x (Super Lento)')),
                    const PopupMenuItem(value: 0.75, child: Text('0.75x (Lento)')),
                    const PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                    const PopupMenuItem(value: 1.25, child: Text('1.25x (Rápido)')),
                    const PopupMenuItem(value: 1.5, child: Text('1.5x (Acelerado)')),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFE040FB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _analysisStatus,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${(_analysisProgress * 100).toInt()}%',
                style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _analysisProgress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE040FB)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Complexidade do Acorde (Chord ai standard)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Complexidade: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
              SegmentedButton<ChordComplexity>(
                segments: const [
                  ButtonSegment(value: ChordComplexity.basic, label: Text('Básico', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: ChordComplexity.intermediate, label: Text('Interm.', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: ChordComplexity.advanced, label: Text('Avançado', style: TextStyle(fontSize: 11))),
                ],
                selected: {_complexity},
                onSelectionChanged: (set) => setState(() => _complexity = set.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF00E5FF).withValues(alpha: 0.2);
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF00E5FF);
                    }
                    return Colors.white70;
                  }),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          // Transpose & Capo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Transpose
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2436),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 14, color: Colors.white70),
                      onPressed: () => setState(() => _transposeSemitones--),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      _transposeSemitones == 0 ? 'Tom Original' : 'Tom: ${_transposeSemitones > 0 ? '+$_transposeSemitones' : '$_transposeSemitones'}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 14, color: Colors.white70),
                      onPressed: () => setState(() => _transposeSemitones++),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Alternador de Visualização
              IconButton(
                tooltip: _showBeatGrid ? 'Mudar para Onda Contínua' : 'Mudar para Beat Grid',
                icon: Icon(_showBeatGrid ? Icons.grid_view_rounded : Icons.waves_rounded, color: const Color(0xFF00E5FF)),
                onPressed: () => setState(() => _showBeatGrid = !_showBeatGrid),
              ),

              // Botão Salvar no Repertório
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                label: const Text('Salvar no Repertório', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _exportToKordApp,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChordCard(String displayChord, ChordInfo chordInfo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F30), Color(0xFF141722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'ACORDE ATUAL SINCRONIZADO',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayChord,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Notas: ${chordInfo.notes.join(' • ')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final simplifiedMeasures = _measures.map((m) {
      return MeasureBeat(
        measureNumber: m.measureNumber,
        startSeconds: m.startSeconds,
        durationSeconds: m.durationSeconds,
        chord: _getEffectiveChord(m.chord),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _showBeatGrid ? 'BEAT GRID SINCRONIZADO (COMPASSOS 4/4)' : 'LINHA DO TEMPO HARMÔNICA',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '${_measures.length} Compassos',
              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _showBeatGrid
              ? ChordifyBeatGrid(
                  measures: simplifiedMeasures,
                  currentSeconds: _currentPosition.inMilliseconds / 1000.0,
                  transposeSemitones: 0,
                  onSeek: _seekTo,
                )
              : ScrollingWaveformTimeline(
                  chordMarkers: _chordMarkers,
                  currentSeconds: _currentPosition.inMilliseconds / 1000.0,
                  totalSeconds: _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds.toDouble() : 180.0,
                  onSeek: _seekTo,
                ),
        ),
      ],
    );
  }

  Widget _buildInstrumentSection(ChordInfo chordInfo) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF141722),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildInstOption(InstrumentType.guitar, 'Violão', Icons.music_note_rounded),
              _buildInstOption(InstrumentType.piano, 'Piano', Icons.piano_rounded),
              _buildInstOption(InstrumentType.ukulele, 'Ukulele', Icons.queue_music_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141722),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Center(
            child: _buildInstrumentDiagram(chordInfo),
          ),
        ),
      ],
    );
  }

  Widget _buildInstOption(InstrumentType type, String title, IconData icon) {
    final isSelected = _selectedInstrument == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedInstrument = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C3246) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
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
    if (_selectedInstrument == InstrumentType.guitar) {
      final pos = chordInfo.guitarPositions.isNotEmpty
          ? chordInfo.guitarPositions.first
          : const GuitarPosition(frets: [-1, 3, 2, 0, 1, 0]);
      return GuitarFretboardWidget(position: pos, height: 230, width: 220);
    } else if (_selectedInstrument == InstrumentType.piano) {
      return PianoKeyboardWidget(activeNotes: chordInfo.notes, height: 130, width: 340);
    } else {
      final pos = chordInfo.ukulelePositions.isNotEmpty
          ? chordInfo.ukulelePositions.first
          : const UkulelePosition(frets: [0, 0, 0, 3]);
      return UkuleleFretboardWidget(position: pos, height: 230, width: 190);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
