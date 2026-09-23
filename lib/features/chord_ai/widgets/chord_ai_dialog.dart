import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../songs/models/song.dart';
import '../../songs/repositories/song_repository.dart';
import '../../songs/widgets/native_chord_diagram.dart';
import '../models/detected_chord.dart';
import '../providers/chord_ai_provider.dart';

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
  final _titleController = TextEditingController(text: 'Minha Composição');
  final _artistController = TextEditingController(text: 'Autor Desconhecido');

  @override
  void initState() {
    super.initState();
    // Inicia a escuta automaticamente ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chordAiProvider.notifier).startListening();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chordAiProvider);
    final notifier = ref.read(chordAiProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 850,
        height: isCompact ? size.height * 0.92 : 720,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131722) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.15),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // ─── Header ───────────────────────────────────────────────────────
            _buildHeader(context, state, notifier, colors),

            // ─── Body (Scrollable) ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // VU Meter & Status Bar
                    _buildAudioStatusBar(state, colors),

                    const SizedBox(height: 16),

                    // Main Detection Panel: Chord display + Diagram
                    if (isCompact) ...[
                      _buildCurrentChordCard(state, colors),
                      const SizedBox(height: 16),
                      _buildDiagramCard(state, colors),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildCurrentChordCard(state, colors)),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _buildDiagramCard(state, colors)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Chromagram Spectrum Equalizer (12 Notes)
                    _buildChromagramEqualizer(state, colors),

                    const SizedBox(height: 16),

                    // Recorded Chords Timeline & Key Estimator
                    _buildTimelineCard(context, state, notifier, colors),
                  ],
                ),
              ),
            ),

            // ─── Bottom Actions Bar ───────────────────────────────────────────
            _buildBottomBar(context, state, notifier, colors),
          ],
        ),
      ),
    );
  }

  // ─── Componentes de UI ──────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    ChordAiState state,
    ChordAiNotifier notifier,
    ColorScheme colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.tertiary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Chord AI',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Badge(
                    label: Text('DETECTOR EM TEMPO REAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.indigo,
                  ),
                ],
              ),
              Text(
                'Identifica acordes e tom pelo som do seu instrumento',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const Spacer(),
          // Close button
          IconButton(
            onPressed: () {
              notifier.stopListening();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close),
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }

  Widget _buildAudioStatusBar(ChordAiState state, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            state.isListening ? Icons.mic : Icons.mic_off,
            color: state.isListening ? Colors.greenAccent : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.statusMessage ?? (state.isListening ? 'Ouvindo...' : 'Pausado'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${(state.audioLevel * 100).toInt()}% Vol',
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.audioLevel,
                    minHeight: 6,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    color: state.audioLevel > 0.7
                        ? Colors.redAccent
                        : (state.audioLevel > 0.3 ? Colors.greenAccent : colors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentChordCard(ChordAiState state, ColorScheme colors) {
    final chord = state.currentChord;
    final hasChord = chord != null;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasChord ? colors.primary.withValues(alpha: 0.5) : colors.outlineVariant.withValues(alpha: 0.3),
          width: hasChord ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note,
                color: hasChord ? colors.primary : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'ACORDE ATUAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: hasChord ? colors.primary : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              hasChord ? chord.chord : '---',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: hasChord ? colors.onSurface : Colors.grey,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (hasChord) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                Chip(
                  label: Text('Confiança: ${(chord.confidence * 100).toInt()}%'),
                  backgroundColor: colors.primaryContainer.withValues(alpha: 0.4),
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontSize: 11),
                  visualDensity: VisualDensity.compact,
                ),
                if (chord.activeNotes.isNotEmpty)
                  Chip(
                    label: Text('Notas: ${chord.activeNotes.join(' • ')}'),
                    backgroundColor: colors.secondaryContainer.withValues(alpha: 0.4),
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 11),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ] else ...[
            Text(
              state.isListening ? 'Toque um acorde no violão ou piano...' : 'Clique em Ouvir para começar',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagramCard(ChordAiState state, ColorScheme colors) {
    final chord = state.currentChord;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DIAGRAMA',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              Text(
                state.instrument == 'guitar' ? 'Violão' : 'Teclado',
                style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          if (chord != null)
            NativeChordDiagram(
              chordName: chord.chord,
              width: 110,
              height: 140,
            )
          else
            const Center(
              child: Icon(Icons.grid_on, size: 48, color: Colors.grey),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildChromagramEqualizer(ChordAiState state, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.equalizer, size: 18),
              const SizedBox(width: 8),
              const Text(
                'CROMAGRAMA DE FREQUÊNCIAS (12 NOTAS)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              const Spacer(),
              if (state.estimatedKey != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.key, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Tom: ${state.estimatedKey}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (index) {
              final note = PitchClass.names[index];
              final energy = (index < state.chromagram.length ? state.chromagram[index] : 0.0).clamp(0.0, 1.0);
              final isActive = energy > 0.45;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 50 * energy + 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colors.primary
                          : colors.primary.withValues(alpha: 0.2 + energy * 0.4),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.6),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(
    BuildContext context,
    ChordAiState state,
    ChordAiNotifier notifier,
    ColorScheme colors,
  ) {
    final recorded = state.recordedChords;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fiber_manual_record,
                size: 16,
                color: state.isRecording ? Colors.redAccent : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'PROGRESSÃO GRAVADA (${recorded.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              const Spacer(),
              // Botão Gravar / Pausar Gravação
              FilledButton.icon(
                onPressed: notifier.toggleRecording,
                icon: Icon(
                  state.isRecording ? Icons.pause : Icons.fiber_manual_record,
                  size: 16,
                ),
                label: Text(state.isRecording ? 'Pausar Gravação' : 'Gravar Sequência'),
                style: FilledButton.styleFrom(
                  backgroundColor: state.isRecording ? Colors.redAccent : colors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (recorded.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: notifier.clearRecordedChords,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Limpar gravação',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (recorded.isEmpty)
            Container(
              height: 54,
              alignment: Alignment.center,
              child: Text(
                'Clique em "Gravar Sequência" e toque os acordes no violão...',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            )
          else
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recorded.length,
                separatorBuilder: (_, __) => const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                itemBuilder: (context, index) {
                  final item = recorded[index];
                  return Chip(
                    label: Text(
                      item.chord,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onDeleted: () => notifier.removeChordAt(index),
                    backgroundColor: colors.surfaceContainerHighest,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ChordAiState state,
    ChordAiNotifier notifier,
    ColorScheme colors,
  ) {
    final recorded = state.recordedChords;
    final hasRecorded = recorded.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          // Toggle Mic Listening
          OutlinedButton.icon(
            onPressed: notifier.toggleListening,
            icon: Icon(state.isListening ? Icons.mic_off : Icons.mic),
            label: Text(state.isListening ? 'Silenciar Mic' : 'Ouvir Mic'),
          ),
          const Spacer(),
          // Copiar Cifra
          if (hasRecorded) ...[
            OutlinedButton.icon(
              onPressed: () {
                final text = state.recordedChords.map((c) => c.chord).join('   ');
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Acordes copiados para a área de transferência!')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar'),
            ),
            const SizedBox(width: 10),
          ],
          // Inserir no Editor (se aberto de dentro do editor)
          if (hasRecorded && widget.onInsertToEditor != null) ...[
            FilledButton.icon(
              onPressed: () {
                final chordText = state.recordedChords.map((c) => '[$c]').join('   ');
                widget.onInsertToEditor!(chordText);
                notifier.stopListening();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.text_fields, size: 16),
              label: const Text('Inserir no Editor'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            ),
            const SizedBox(width: 10),
          ],
          // Salvar como Nova Música no Repertório
          FilledButton.icon(
            onPressed: hasRecorded ? () => _showSaveSongDialog(context, state, notifier) : null,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Salvar no Repertório'),
          ),
        ],
      ),
    );
  }

  void _showSaveSongDialog(
    BuildContext context,
    ChordAiState state,
    ChordAiNotifier notifier,
  ) {
    final estimatedKey = state.estimatedKey != null
        ? state.estimatedKey!.replaceAll(RegExp(r'.*\('), '').replaceAll(')', '')
        : 'C';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar Música Detectada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título da Música'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artista / Ministério'),
            ),
            const SizedBox(height: 12),
            Text(
              'Tom detectado: $estimatedKey (${state.recordedChords.length} acordes gravados)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final title = _titleController.text.trim().isEmpty ? 'Nova Música' : _titleController.text.trim();
              final artist = _artistController.text.trim().isEmpty ? 'Autor Desconhecido' : _artistController.text.trim();
              final content = notifier.generateSongContent(
                title: title,
                artist: artist,
                key: estimatedKey,
              );

              final song = Song(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                artist: artist,
                key: estimatedKey,
                bpm: 70,
                content: content,
              );

              await ref.read(songRepositoryProvider).createSong(song);

              if (context.mounted) {
                Navigator.of(ctx).pop(); // fecha modal de salvar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Música "$title" salva no repertório com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
