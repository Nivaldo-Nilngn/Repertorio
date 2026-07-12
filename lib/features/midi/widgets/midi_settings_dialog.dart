import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/midi_providers.dart';

class MidiSettingsDialog extends ConsumerWidget {
  const MidiSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(midiProvider);
    final notifier = ref.read(midiProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    if (!state.isSupported) {
      return AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Controle MIDI'),
        content: const Text('A API Web MIDI não é suportada neste navegador.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('FECHAR')),
        ],
      );
    }

    final activeProfile = state.activeProfile;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.all(24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Row(
        children: [
          Icon(Icons.piano, color: colors.primary, size: 28),
          const SizedBox(width: 12),
          const Text('Controles MIDI', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: state.inputs.isNotEmpty ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: state.inputs.isNotEmpty ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.inputs.isNotEmpty ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  state.inputs.isNotEmpty ? 'Conectado' : 'Desconectado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: state.inputs.isNotEmpty ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 950,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Settings)
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Dispositivo de Entrada', style: TextStyle(fontWeight: FontWeight.w600, color: colors.primary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: state.activeInputId,
                    dropdownColor: colors.surfaceContainerHighest,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: state.inputs.isEmpty
                        ? [const DropdownMenuItem(value: null, child: Text('Nenhum dispositivo encontrado'))]
                        : state.inputs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setActiveInput(val);
                    },
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Perfil de Controle', style: TextStyle(fontWeight: FontWeight.w600, color: colors.primary)),
                      TextButton.icon(
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('Novo Perfil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _showNewProfileDialog(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: state.activeProfileId,
                    dropdownColor: colors.surfaceContainerHighest,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: state.profiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setActiveProfile(val);
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 32),
            
            // Right Column (Mappings)
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ações Mapeáveis', style: TextStyle(fontWeight: FontWeight.w600, color: colors.primary, fontSize: 18)),
                    const SizedBox(height: 16),
                    
                    _buildSectionTitle('Navegação de Repertório', Icons.library_music, colors),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        _buildMappingRow('Próxima Música', 'next_song', Icons.skip_next, activeProfile, state, notifier, colors),
                        _buildMappingRow('Música Anterior', 'prev_song', Icons.skip_previous, activeProfile, state, notifier, colors),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildSectionTitle('Controle de Rolagem', Icons.swap_vert, colors),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        _buildMappingRow('Iniciar/Pausar Rolagem', 'toggle_scroll', Icons.play_arrow, activeProfile, state, notifier, colors),
                        _buildMappingRow('Aumentar Velocidade', 'speed_up', Icons.fast_forward, activeProfile, state, notifier, colors),
                        _buildMappingRow('Diminuir Velocidade', 'speed_down', Icons.fast_rewind, activeProfile, state, notifier, colors),
                        _buildMappingRow('Página p/ Baixo (Manual)', 'scroll_down', Icons.arrow_downward, activeProfile, state, notifier, colors),
                        _buildMappingRow('Página p/ Cima (Manual)', 'scroll_up', Icons.arrow_upward, activeProfile, state, notifier, colors),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildSectionTitle('Tonalidade (Transposição)', Icons.music_note, colors),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        _buildMappingRow('Subir Tom (+)', 'tone_up', Icons.arrow_drop_up, activeProfile, state, notifier, colors),
                        _buildMappingRow('Descer Tom (-)', 'tone_down', Icons.arrow_drop_down, activeProfile, state, notifier, colors),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: colors.outline.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _buildMappingRow(
    String label,
    String actionKey,
    IconData icon,
    activeProfile,
    MidiState state,
    MidiNotifier notifier,
    ColorScheme colors,
  ) {
    final mapping = activeProfile.mappings[actionKey];
    final isLearningThis = state.isLearning && state.learningAction == actionKey;

    String mappingText = '[Nenhum botão atribuído]';
    if (isLearningThis) {
      mappingText = 'Aguardando sinal MIDI...';
    } else if (mapping != null) {
      mappingText = '[Sinal ${mapping.command}, Nota/CC ${mapping.noteOrCc}]';
    }

    return Container(
      width: 260,
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: isLearningThis ? colors.primary.withOpacity(0.08) : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLearningThis ? colors.primary.withOpacity(0.5) : colors.outline.withOpacity(0.2),
          width: isLearningThis ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: isLearningThis ? colors.primary : colors.primary.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isLearningThis ? colors.primary : colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  mappingText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isLearningThis ? colors.primary.withOpacity(0.8) : colors.onSurfaceVariant,
                    fontStyle: isLearningThis ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (isLearningThis)
            FilledButton.tonal(
              onPressed: () => notifier.cancelLearning(),
              style: FilledButton.styleFrom(
                backgroundColor: colors.errorContainer,
                foregroundColor: colors.onErrorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(60, 32),
              ),
              child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            )
          else
            OutlinedButton(
              onPressed: () => notifier.startLearning(actionKey),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.primary.withOpacity(0.5)),
                foregroundColor: colors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(60, 32),
              ),
              child: const Text('MAPEAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  void _showNewProfileDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Perfil MIDI', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nome do Perfil (ex: Alesis Palco)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(midiProvider.notifier).addProfile(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('CRIAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
