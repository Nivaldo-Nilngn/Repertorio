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
      title: Row(
        children: [
          const Text('Controles MIDI'),
          const Spacer(),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.inputs.isNotEmpty ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state.inputs.isNotEmpty ? 'Conectado' : 'Desconectado',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Device Selection
              const Text('Dispositivo de Entrada', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: state.activeInputId,
                dropdownColor: colors.surfaceContainerHighest,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: state.inputs.isEmpty
                    ? [const DropdownMenuItem(value: null, child: Text('Nenhum dispositivo encontrado'))]
                    : state.inputs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                onChanged: (val) {
                  if (val != null) notifier.setActiveInput(val);
                },
              ),
              const SizedBox(height: 24),

              // Profile Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Perfil de Controle', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Novo Perfil', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showNewProfileDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: state.activeProfileId,
                dropdownColor: colors.surfaceContainerHighest,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: state.profiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (val) {
                  if (val != null) notifier.setActiveProfile(val);
                },
              ),
              const SizedBox(height: 24),

              // Mappings
              const Text('Ações Mapeáveis', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildMappingRow('Próxima Música', 'next_song', activeProfile, state, notifier, colors),
              _buildMappingRow('Música Anterior', 'prev_song', activeProfile, state, notifier, colors),
              _buildMappingRow('Subir Tom (+)', 'tone_up', activeProfile, state, notifier, colors),
              _buildMappingRow('Descer Tom (-)', 'tone_down', activeProfile, state, notifier, colors),
              _buildMappingRow('Iniciar/Pausar Rolagem', 'toggle_scroll', activeProfile, state, notifier, colors),
              _buildMappingRow('Aumentar Velocidade de Rolagem', 'speed_up', activeProfile, state, notifier, colors),
              _buildMappingRow('Diminuir Velocidade de Rolagem', 'speed_down', activeProfile, state, notifier, colors),
              _buildMappingRow('Rolar Página Manualmente Abaixo', 'scroll_down', activeProfile, state, notifier, colors),
              _buildMappingRow('Rolar Página Manualmente Acima', 'scroll_up', activeProfile, state, notifier, colors),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('FECHAR'),
        ),
      ],
    );
  }

  Widget _buildMappingRow(
    String label,
    String actionKey,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                Text(
                  mappingText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isLearningThis ? Colors.amber : colors.onSurfaceVariant,
                    fontStyle: isLearningThis ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isLearningThis)
            OutlinedButton(
              onPressed: () => notifier.cancelLearning(),
              child: const Text('CANCELAR'),
            )
          else
            OutlinedButton(
              onPressed: () => notifier.startLearning(actionKey),
              child: const Text('MAPEAR'),
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
        title: const Text('Novo Perfil MIDI'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nome do Perfil (ex: Alesis Palco)'),
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
            child: const Text('CRIAR'),
          ),
        ],
      ),
    );
  }
}
