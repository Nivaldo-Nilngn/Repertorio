import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../manager/providers/manager_providers.dart';
import '../models/chord_data.dart';
import '../services/audio_recording_service.dart';
import '../services/chord_repository.dart';
import '../widgets/guitar_fretboard.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/ukulele_fretboard.dart';

class ChordAiDialog extends ConsumerStatefulWidget {
  final void Function(String generatedText)? onInsertToEditor;

  const ChordAiDialog({super.key, this.onInsertToEditor});

  static Future<void> show(
    BuildContext context, {
    void Function(String generatedText)? onInsertToEditor,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ChordAiDialog(onInsertToEditor: onInsertToEditor),
    );
  }

  @override
  ConsumerState<ChordAiDialog> createState() => _ChordAiDialogState();
}

class _ChordAiDialogState extends ConsumerState<ChordAiDialog> {
  final AudioRecordingService _audioService = AudioRecordingService();
  final ChordRepository _chordRepository = ChordRepository();
  int _selectedInstrument = 0; // 0: Guitar, 1: Piano, 2: Ukulele
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _chordRepository.init();
    if (mounted) {
      setState(() => _isInit = true);
      _audioService.startListening();
      _audioService.addListener(_onAudioUpdate);
    }
  }

  void _onAudioUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioUpdate);
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentChord = _audioService.currentChord;
    final confidence = (_audioService.confidence * 100).toInt();
    final history = _audioService.chordHistory;
    final chordInfo = _chordRepository.getChord(currentChord);

    return Dialog(
      backgroundColor: const Color(0xFF141722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFFE040FB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mic_rounded, size: 20, color: Colors.black),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chord AI - Reconhecimento Rápido',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Toque seu instrumento para capturar e inserir na cifra',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Card Principal do Acorde Detectado
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0E121B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: currentChord != '...'
                      ? const Color(0xFF00E5FF)
                      : Colors.white12,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    currentChord,
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _audioService.isListening
                            ? Icons.fiber_manual_record_rounded
                            : Icons.pause_circle_rounded,
                        size: 14,
                        color: _audioService.isListening
                            ? const Color(0xFF10B981)
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _audioService.isListening
                            ? 'Ouvindo microfone... (Precisão: $confidence%)'
                            : 'Pausado',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seletor de Diagrama de Instrumento
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInstrumentChip(0, 'Violão', Icons.music_note_rounded),
                const SizedBox(width: 8),
                _buildInstrumentChip(1, 'Teclado', Icons.piano_rounded),
                const SizedBox(width: 8),
                _buildInstrumentChip(2, 'Ukulele', Icons.queue_music_rounded),
              ],
            ),
            const SizedBox(height: 12),

            // Diagrama do Instrumento
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E121B),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _buildInstrumentDiagram(chordInfo),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Histórico de Acordes Recentes
            if (history.isNotEmpty) ...[
              const Text(
                'Sequência Detectada:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length > 8 ? 8 : history.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final item = history[history.length - 1 - i];
                    return ActionChip(
                      backgroundColor: const Color(0xFF1C2234),
                      label: Text(item.chordName, style: const TextStyle(color: Colors.white)),
                      onPressed: () {
                        widget.onInsertToEditor?.call('[${item.chordName}]');
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Abrir Jam Player Completo'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.chordAi);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      currentChord != '...'
                          ? 'Inserir [$currentChord]'
                          : 'Inserir no Editor',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: currentChord != '...'
                        ? () {
                            widget.onInsertToEditor?.call('[$currentChord]');
                            Navigator.of(context).pop();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstrumentChip(int index, String label, IconData icon) {
    final isSelected = _selectedInstrument == index;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12)),
        ],
      ),
      selectedColor: const Color(0xFF00E5FF),
      backgroundColor: const Color(0xFF0E121B),
      onSelected: (_) {
        setState(() => _selectedInstrument = index);
      },
    );
  }

  Widget _buildInstrumentDiagram(ChordInfo? chordInfo) {
    if (chordInfo == null) {
      return const Text(
        'Toque uma nota ou acorde para visualizar o diagrama',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
    }

    if (_selectedInstrument == 0) {
      final pos = chordInfo.guitarPositions.isNotEmpty
          ? chordInfo.guitarPositions.first
          : const GuitarPosition(frets: [0, 0, 0, 0, 0, 0]);
      return GuitarFretboardWidget(position: pos, height: 220, width: 200);
    } else if (_selectedInstrument == 1) {
      return PianoKeyboardWidget(activeNotes: chordInfo.notes, height: 110);
    } else {
      final pos = chordInfo.ukulelePositions.isNotEmpty
          ? chordInfo.ukulelePositions.first
          : const UkulelePosition(frets: [0, 0, 0, 0]);
      return UkuleleFretboardWidget(position: pos, height: 220, width: 180);
    }
  }
}
