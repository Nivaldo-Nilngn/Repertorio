import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../songs/models/song.dart';
import '../../songs/repositories/song_repository.dart';
import '../../manager/providers/manager_providers.dart';
import '../../manager/providers/editor_provider.dart';
import '../services/chord_repository.dart';
import '../services/audio_recording_service.dart';
import '../services/setlist_repository.dart';
import '../views/featured_setlists_tab.dart';
import '../views/live_listening_tab.dart';
import '../views/audio_file_tab.dart';
import '../views/chord_dictionary_tab.dart';
import '../views/mic_listening_tab.dart';

class ChordAiWorkspace extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const ChordAiWorkspace({super.key, this.onClose});

  @override
  ConsumerState<ChordAiWorkspace> createState() => _ChordAiWorkspaceState();
}

class _ChordAiWorkspaceState extends ConsumerState<ChordAiWorkspace> {
  final ChordRepository _chordRepository = ChordRepository();
  final AudioRecordingService _audioService = AudioRecordingService();
  final GlobalKey<LiveListeningTabState> _playerKey =
      GlobalKey<LiveListeningTabState>();

  bool _isLoading = true;
  int _currentTabIndex = 0; // 0: Setlists, 1: Jam Player, 2: Dicionário, 3: Mic

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _chordRepository.init();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  void _onSongSelectedFromSetlist(FeaturedSong song) {
    setState(() {
      _currentTabIndex = 1; // Alterna para a aba Jam Player
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playerKey.currentState?.loadSong(song, triggerAnalysis: true);
    });
  }

  /// Converte a música atual do Jam Player em formato ChordPro e salva no repertório do KordApp
  Future<void> _exportSongToKordApp() async {
    final playerState = _playerKey.currentState;
    final currentSong = playerState?.currentSong ??
        const FeaturedSong(
          id: 'temp',
          title: 'Música Reconhecida',
          artist: 'Chord AI',
          categoryId: 'ai',
          key: 'C',
          bpm: 120,
          durationSeconds: 180,
          thumbnailUrl: '',
          jamsCount: '1',
          chordMarkers: [],
          measures: [],
        );

    // Constrói o conteúdo em ChordPro baseado nos compassos e acordes da música
    final buffer = StringBuffer();
    buffer.writeln('{title: ${currentSong.title}}');
    buffer.writeln('{artist: ${currentSong.artist}}');
    buffer.writeln('{key: ${currentSong.key}}');
    if (currentSong.bpm > 0) {
      buffer.writeln('{tempo: ${currentSong.bpm}}');
    }
    buffer.writeln();
    buffer.writeln('# Cifra gerada via Chordify & Chord AI');
    buffer.writeln();

    if (currentSong.measures.isNotEmpty) {
      // Agrupa compassos em linhas de 4
      int count = 0;
      for (final m in currentSong.measures) {
        final chord = m.chord.trim();
        if (chord.isNotEmpty && chord != 'N/A' && chord != '...') {
          buffer.write('[$chord]   ');
        } else {
          buffer.write('[C]   ');
        }
        count++;
        if (count % 4 == 0) {
          buffer.writeln();
        }
      }
      buffer.writeln();
    } else if (currentSong.chordMarkers.isNotEmpty) {
      for (final marker in currentSong.chordMarkers) {
        buffer.write('[${marker.chord}] ');
      }
      buffer.writeln();
    } else {
      buffer.writeln('[C] [G] [Am] [F]');
      buffer.writeln('Letra da música com acordes detectados em tempo real...');
    }

    final newSong = Song(
      id: 'chordai_${DateTime.now().millisecondsSinceEpoch}',
      title: currentSong.title,
      artist: currentSong.artist,
      key: currentSong.key,
      bpm: currentSong.bpm,
      content: buffer.toString(),
      tags: ['Chord AI', 'YouTube'],
    );

    try {
      await ref.read(songRepositoryProvider).createSong(newSong);
      ref.read(selectedSongIdProvider.notifier).select(newSong.id);

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
                    'Música "${newSong.title}" salva com sucesso no seu Repertório!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Ver Cifra',
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
            content: Text('Erro ao salvar música: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0D14),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFFE040FB)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    size: 44, color: Colors.black),
              ),
              const SizedBox(height: 24),
              const Text(
                'Chordify & Chord ai',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inicializando motor web e 17.000+ acordes...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E121B),
        elevation: 0,
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Voltar ao Repertório',
                onPressed: widget.onClose,
              )
            : null,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFFE040FB)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.queue_music_rounded,
                    size: 18, color: Colors.black),
              ),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                        text: 'Chordify ',
                        style: TextStyle(color: Colors.white)),
                    TextSpan(
                        text: '& Chord ai',
                        style: TextStyle(color: Color(0xFF00E5FF))),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              _buildNavTab(0, Icons.search_rounded, 'Início'),
              const SizedBox(width: 6),
              _buildNavTab(1, Icons.play_circle_fill_rounded, 'Jam Player'),
              const SizedBox(width: 6),
              _buildNavTab(2, Icons.audio_file_rounded, 'Áudio'),
              const SizedBox(width: 6),
              _buildNavTab(3, Icons.menu_book_rounded, 'Dicionário'),
              const SizedBox(width: 6),
              _buildNavTab(4, Icons.mic_rounded, 'Microfone'),
            ],
          ),
        ),
        actions: [
          // Botão Exportar para o Repertório do KordApp
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFF00E5FF),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.bookmark_add_rounded, size: 18),
            label: const Text('Salvar no Repertório', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _exportSongToKordApp,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sobre o Sistema',
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
            onPressed: () => _showAboutDialog(context),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Fechar',
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: widget.onClose,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          // 0. Featured Setlists (estilo chordify.net/setlists/featured)
          FeaturedSetlistsTab(
            onSongSelected: _onSongSelectedFromSetlist,
          ),

          // 1. Live Listening / Jam Player com YouTube e Beat Grid sincronizado
          LiveListeningTab(
            key: _playerKey,
            audioService: _audioService,
            chordRepository: _chordRepository,
            onBackToSearch: () {
              setState(() => _currentTabIndex = 0);
            },
          ),

          // 2. Reconhecimento de Áudio (MP3 / WAV / M4A) com Chord ai
          AudioFileTab(
            chordRepository: _chordRepository,
          ),

          // 3. Dicionário de 17.000+ Acordes
          ChordDictionaryTab(
            chordRepository: _chordRepository,
          ),

          // 4. Reconhecimento via Microfone Acústico (Chord ai)
          MicListeningTab(
            audioService: _audioService,
            chordRepository: _chordRepository,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _currentTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Chordify & Chord ai Integrado ao KordApp', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plataforma completa de reconhecimento e sincronização musical integrada:',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            SizedBox(height: 12),
            Text(
              '• Setlists em Destaque: Explore repertórios nacionais e internacionais com compassos e BPMs.\n'
              '• Jam Player & YouTube: Toque sincronizado com vídeo/áudio sem problemas de CORS.\n'
              '• Beat Grid (Chordify): Compassos com marcação de tempo e acordes em tempo real.\n'
              '• Diagramas Fretboard & Teclado: Violão, Piano e Ukulele com posições e pestanas.\n'
              '• Dicionário com 17.000+ Acordes: Busca de variações, digitações e notas.\n'
              '• Microfone (Chord ai): Detecção acústica via FFT e cromagrama de 12 notas.\n'
              '• Exportar para KordApp: Salve qualquer música analisada diretamente no seu repertório!',
              style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
  }
}
