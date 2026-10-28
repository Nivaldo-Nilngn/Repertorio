import 'package:flutter/material.dart';
import '../services/audio_recording_service.dart';
import '../services/chord_repository.dart';
import '../widgets/guitar_fretboard.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/waveform_visualizer.dart';

class MicListeningTab extends StatefulWidget {
  final AudioRecordingService audioService;
  final ChordRepository chordRepository;

  const MicListeningTab({
    super.key,
    required this.audioService,
    required this.chordRepository,
  });

  @override
  State<MicListeningTab> createState() => _MicListeningTabState();
}

class _MicListeningTabState extends State<MicListeningTab> {
  @override
  void initState() {
    super.initState();
    widget.audioService.addListener(_onAudioUpdate);
  }

  @override
  void dispose() {
    widget.audioService.removeListener(_onAudioUpdate);
    super.dispose();
  }

  void _onAudioUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.audioService.isListening;
    final currentChord = widget.audioService.currentChord;
    final chordInfo = widget.chordRepository.getChord(currentChord);

    final guitarPos = chordInfo.guitarPositions.isNotEmpty
        ? chordInfo.guitarPositions.first
        : null;

    final notes = chordInfo.notes;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Banner de Instrução
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141724),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded,
                        color: Color(0xFF00E5FF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reconhecimento Via Microfone (Chord ai)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toque seu violão ou piano próximo ao microfone do computador/navegador para identificar o acorde em tempo real via FFT.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botão Principal de Escuta
            GestureDetector(
              onTap: () {
                if (isListening) {
                  widget.audioService.stopListening();
                } else {
                  widget.audioService.startListening();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isListening
                        ? [const Color(0xFFFF5252), const Color(0xFFFF1744)]
                        : [const Color(0xFF00E5FF), const Color(0xFF00B0FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isListening
                              ? const Color(0xFFFF5252)
                              : const Color(0xFF00E5FF))
                          .withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 48,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isListening ? 'Ouvindo instrumento...' : 'Clique para Iniciar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isListening ? const Color(0xFFFF5252) : Colors.white70,
              ),
            ),
            const SizedBox(height: 24),

            // Visualizador de Espectro / Onda
            WaveformVisualizerWidget(
              isListening: isListening,
              chromagram: widget.audioService.chromagram,
              rms: widget.audioService.rms,
            ),
            const SizedBox(height: 24),

            // Acorde Detectado e Diagramas
            Text(
              currentChord,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Diagramas Lado a Lado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (guitarPos != null)
                  Flexible(
                    child: GuitarFretboardWidget(
                      position: guitarPos,
                      width: 190,
                      height: 230,
                    ),
                  ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    children: [
                      PianoKeyboardWidget(
                        activeNotes: notes,
                        width: 280,
                        height: 120,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Notas: ${notes.join(' • ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
