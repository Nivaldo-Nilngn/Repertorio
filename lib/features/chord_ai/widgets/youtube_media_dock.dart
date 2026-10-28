import 'package:flutter/material.dart';
import '../services/youtube_service.dart';

class YouTubeMediaDock extends StatefulWidget {
  final YouTubeVideoItem? currentVideo;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackSpeed;
  final int pitchSemitones;
  final VoidCallback onSelectMedia;
  final VoidCallback onTogglePlay;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<int> onPitchChanged;
  final VoidCallback? onClose;
  final Widget? videoPlayer;

  const YouTubeMediaDock({
    super.key,
    required this.currentVideo,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    this.playbackSpeed = 1.0,
    this.pitchSemitones = 0,
    required this.onSelectMedia,
    required this.onTogglePlay,
    required this.onRewind,
    required this.onForward,
    required this.onSeek,
    required this.onSpeedChanged,
    required this.onPitchChanged,
    this.onClose,
    this.videoPlayer,
  });

  @override
  State<YouTubeMediaDock> createState() => _YouTubeMediaDockState();
}

class _YouTubeMediaDockState extends State<YouTubeMediaDock> {
  double _dragValue = -1.0;
  bool _isLooping = false;
  bool _showVideoPreview = false;

  @override
  Widget build(BuildContext context) {
    final max = widget.totalDuration.inMilliseconds > 0
        ? widget.totalDuration.inMilliseconds / 1000.0
        : 1.0;
    final currentSeconds = widget.currentPosition.inMilliseconds / 1000.0;
    final sliderValue =
        (_dragValue >= 0 ? _dragValue : currentSeconds).clamp(0.0, max);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1224),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Se o usuário optar por ver o mini player do YouTube
            if (_showVideoPreview && widget.videoPlayer != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                constraints: const BoxConstraints(maxHeight: 180),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.videoPlayer!,
                  ),
                ),
              ),

            // 1. Linha do Tempo e Waveform Linear (Estilo Chorda)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    _formatTime(currentSeconds),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFF2F6BFF),
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                        thumbColor: const Color(0xFF00D2FF),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayColor: const Color(0xFF2F6BFF).withValues(alpha: 0.2),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: sliderValue,
                        max: max,
                        onChanged: (val) {
                          setState(() => _dragValue = val);
                        },
                        onChangeEnd: (val) {
                          widget.onSeek(Duration(milliseconds: (val * 1000).round()));
                          setState(() => _dragValue = -1.0);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(max),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Barra de Controles Principais (Estilo Chorda)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 600;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Esquerda: Velocidade, Loop, Toggle Vídeo
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Velocidade
                          _buildPillButton(
                            label: '${widget.playbackSpeed}x',
                            icon: Icons.speed_rounded,
                            onTap: () {
                              final speeds = [0.75, 1.0, 1.25, 1.5];
                              final nextIdx = (speeds.indexOf(widget.playbackSpeed) + 1) % speeds.length;
                              widget.onSpeedChanged(speeds[nextIdx]);
                            },
                          ),
                          const SizedBox(width: 8),

                          // Loop
                          _buildPillButton(
                            label: 'Loop',
                            icon: Icons.repeat_rounded,
                            isActive: _isLooping,
                            onTap: () {
                              setState(() => _isLooping = !_isLooping);
                            },
                          ),

                          if (!isCompact && widget.videoPlayer != null) ...[
                            const SizedBox(width: 8),
                            _buildPillButton(
                              label: _showVideoPreview ? 'Ocultar Vídeo' : 'Ver Vídeo',
                              icon: Icons.video_library_rounded,
                              isActive: _showVideoPreview,
                              onTap: () {
                                setState(() => _showVideoPreview = !_showVideoPreview);
                              },
                            ),
                          ],
                        ],
                      ),

                      // Centro: Voltar 5s, PLAY/PAUSE Circular Neon, Avançar 5s
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_5_rounded, color: Colors.white70, size: 26),
                            tooltip: 'Retroceder 5 segundos',
                            onPressed: widget.onRewind,
                          ),
                          const SizedBox(width: 8),

                          // Botão Play/Pause Neon Chorda
                          InkWell(
                            onTap: widget.onTogglePlay,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2F6BFF), Color(0xFF00D2FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2F6BFF).withValues(alpha: 0.5),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.forward_5_rounded, color: Colors.white70, size: 26),
                            tooltip: 'Avançar 5 segundos',
                            onPressed: widget.onForward,
                          ),
                        ],
                      ),

                      // Direita: Tom e Capo
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Controle de Tom (- Tom 0 +)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181D35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (widget.pitchSemitones > -6) {
                                      widget.onPitchChanged(widget.pitchSemitones - 1);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Icon(Icons.remove, size: 14, color: Colors.white70),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    'Tom ${widget.pitchSemitones >= 0 ? "+${widget.pitchSemitones}" : widget.pitchSemitones}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    if (widget.pitchSemitones < 6) {
                                      widget.onPitchChanged(widget.pitchSemitones + 1);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Icon(Icons.add, size: 14, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (!isCompact) ...[
                            const SizedBox(width: 8),
                            _buildPillButton(
                              label: 'Buscar',
                              icon: Icons.search_rounded,
                              onTap: widget.onSelectMedia,
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String label,
    required IconData icon,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2F6BFF).withValues(alpha: 0.25)
              : const Color(0xFF181D35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2F6BFF)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? const Color(0xFF00D2FF) : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final s = seconds.toInt();
    final m = s ~/ 60;
    final remSec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${remSec.toString().padLeft(2, '0')}';
  }
}
