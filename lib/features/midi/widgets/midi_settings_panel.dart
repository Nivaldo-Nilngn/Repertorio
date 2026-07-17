import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/midi_providers.dart';
import '../models/midi_profile.dart';
import '../services/midi_web_service.dart' as web_midi;

class MidiSettingsPanel extends ConsumerWidget {
  const MidiSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(midiProvider);
    final notifier = ref.read(midiProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (!state.isSupported) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Controle MIDI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('A API Web MIDI não é suportada neste navegador.'),
          ],
        ),
      );
    }

    final activeProfile = state.activeProfile;

    final topBar = Row(
      children: [
        Icon(Icons.piano, color: colors.primary, size: 28),
        const SizedBox(width: 12),
        const Text('Controles MIDI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
      ],
    );

    final leftColumn = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.settings_input_component, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text('Dispositivos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colors.onSurface)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Recarregar Dispositivos',
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text('Dispositivo de Entrada (Input)', style: TextStyle(fontWeight: FontWeight.w600, color: colors.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 6),
          _buildDropdown<String>(
            value: state.activeInputId,
            items: state.inputs.isEmpty
                ? [const DropdownMenuItem(value: null, child: Text('Nenhum input'))]
                : state.inputs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
            onChanged: (val) { if (val != null) notifier.setActiveInput(val); },
            colors: colors,
          ),
          const SizedBox(height: 16),
          
          Text('Dispositivo de Saída (Output)', style: TextStyle(fontWeight: FontWeight.w600, color: colors.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 6),
          _buildDropdown<String>(
            value: state.activeOutputId,
            items: state.outputs.isEmpty
                ? [const DropdownMenuItem(value: null, child: Text('Nenhum output'))]
                : state.outputs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
            onChanged: (val) { if (val != null) notifier.setActiveOutput(val); },
            colors: colors,
          ),
          
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sinal MIDI', style: TextStyle(fontWeight: FontWeight.w600, color: colors.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isReceivingSignal ? colors.primary : colors.surfaceContainerHighest,
                      boxShadow: state.isReceivingSignal ? [
                        BoxShadow(color: colors.primary.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)
                      ] : [],
                      border: Border.all(color: state.isReceivingSignal ? colors.primary : colors.outline.withOpacity(0.3)),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Canal MIDI', style: TextStyle(fontWeight: FontWeight.w600, color: colors.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: isMobile ? 120 : 140,
                    child: _buildDropdown<int>(
                      value: state.activeChannel,
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('Omni (Todos)')),
                        ...List.generate(16, (i) => DropdownMenuItem(value: i + 1, child: Text('Canal ${i + 1}'))),
                      ],
                      onChanged: (val) { if (val != null) notifier.setActiveChannel(val); },
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (state.recentEvents.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outline.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, size: 14, color: colors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('Últimos Sinais Recebidos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...state.recentEvents.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(e, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: colors.primary)),
                  )),
                ],
              ),
            ),
          ],

          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Perfil Ativo', style: TextStyle(fontWeight: FontWeight.w600, color: colors.primary)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8, vertical: 4),
                ),
                onPressed: () => _showNewProfileDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDropdown<String>(
                  value: state.activeProfileId,
                  items: state.profiles.map((p) => DropdownMenuItem<String>(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (val) { if (val != null) notifier.setActiveProfile(val); },
                  colors: colors,
                ),
              ),
              if (state.profiles.length > 1) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: colors.error,
                  tooltip: 'Apagar Perfil',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colors.surfaceContainerHigh,
                        title: const Text('Apagar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('Tem certeza que deseja apagar o perfil ativo? Esta ação não pode ser desfeita.'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: colors.error),
                            onPressed: () {
                              notifier.deleteProfile(state.activeProfileId);
                              Navigator.pop(ctx);
                            },
                            child: const Text('APAGAR', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Limpar Mapeamentos deste Perfil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: colors.error.withOpacity(0.3))),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: colors.surfaceContainerHigh,
                    title: const Text('Limpar Tudo', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('Tem certeza que deseja remover TODOS os mapeamentos deste perfil?'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: colors.error),
                        onPressed: () {
                          notifier.clearAllMappings();
                          Navigator.pop(ctx);
                        },
                        child: const Text('LIMPAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.activeOutputId != null ? () => notifier.triggerPanic() : null,
                  icon: const Icon(Icons.warning_amber_rounded, size: 20),
                  label: const Text('Panic', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: state.inputs.isNotEmpty ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: state.inputs.isNotEmpty ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.inputs.isNotEmpty ? Colors.green : Colors.red,
                          boxShadow: state.inputs.isNotEmpty ? [
                            BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
                          ] : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.inputs.isNotEmpty ? 'Conectado' : 'Desconectado',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: state.inputs.isNotEmpty ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final rightColumn = Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ações Mapeáveis', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 20)),
              Text('Clique em MAPEAR e pressione o botão no seu controlador.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 24),
              _buildActionGroup('Navegação de Repertório', Icons.library_music, colors, [
                _buildMappingRow('Próxima Música', 'next_song', Icons.skip_next, activeProfile, state, notifier, colors),
                _buildMappingRow('Música Anterior', 'prev_song', Icons.skip_previous, activeProfile, state, notifier, colors),
              ]),

              _buildActionGroup('Controle de Rolagem', Icons.swap_vert, colors, [
                _buildMappingRow('Iniciar/Pausar Rolagem', 'toggle_scroll', Icons.play_arrow, activeProfile, state, notifier, colors),
                _buildMappingRow('Parar Rolagem', 'stop_scroll', Icons.stop, activeProfile, state, notifier, colors),
                _buildMappingRow('Aumentar Velocidade', 'speed_up', Icons.fast_forward, activeProfile, state, notifier, colors),
                _buildMappingRow('Diminuir Velocidade', 'speed_down', Icons.fast_rewind, activeProfile, state, notifier, colors),
                _buildMappingRow('Página p/ Baixo', 'scroll_down', Icons.arrow_downward, activeProfile, state, notifier, colors),
                _buildMappingRow('Página p/ Cima', 'scroll_up', Icons.arrow_upward, activeProfile, state, notifier, colors),
              ]),

              _buildActionGroup('Tonalidade (Transposição)', Icons.music_note, colors, [
                _buildMappingRow('Subir Tom (+)', 'tone_up', Icons.arrow_drop_up, activeProfile, state, notifier, colors),
                _buildMappingRow('Descer Tom (-)', 'tone_down', Icons.arrow_drop_down, activeProfile, state, notifier, colors),
                _buildMappingRow('Resetar Tom (Original)', 'tone_reset', Icons.restore, activeProfile, state, notifier, colors),
              ]),

              _buildActionGroup('Performance & Mixer', Icons.tune, colors, [
                _buildMappingRow('Volume Geral', 'volume_master', Icons.volume_up, activeProfile, state, notifier, colors),
                _buildMappingRow('Mute (Cortar Som)', 'mute_toggle', Icons.volume_off, activeProfile, state, notifier, colors),
                _buildMappingRow('Trocar Timbre', 'patch_change', Icons.piano, activeProfile, state, notifier, colors),
                _buildMappingRow('Panic (Silenciar Tudo)', 'panic', Icons.warning_amber, activeProfile, state, notifier, colors),
              ]),

              _buildActionGroup('Metrônomo e Ritmo', Icons.timer, colors, [
                _buildMappingRow('Ligar/Desligar Metrônomo', 'metronome_toggle', Icons.play_arrow, activeProfile, state, notifier, colors),
                _buildMappingRow('Tap Tempo', 'tap_tempo', Icons.touch_app, activeProfile, state, notifier, colors),
              ]),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: isMobile
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  topBar,
                  const SizedBox(height: 16),
                  leftColumn,
                  const SizedBox(height: 24),
                  rightColumn,
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      topBar,
                      const SizedBox(height: 32),
                      leftColumn,
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(flex: 6, child: rightColumn),
              ],
            ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required ColorScheme colors,
  }) {
    // Se o valor fornecido não existir na lista de itens (evitando erro no Dropdown), defina como nulo
    final validValue = items.any((item) => item.value == value) ? value : null;

    return DropdownButtonFormField<T>(
      isExpanded: true,
      value: validValue,
      dropdownColor: colors.surfaceContainerHigh,
      icon: Icon(Icons.arrow_drop_down, color: colors.onSurfaceVariant),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildActionGroup(
    String title,
    IconData icon,
    ColorScheme colors,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline.withOpacity(0.15)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              if (!isWide) {
                return Column(
                  children: [
                    for (int i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i < children.length - 1)
                        Divider(height: 1, color: colors.outline.withOpacity(0.1)),
                    ]
                  ],
                );
              }

              final rows = <Widget>[];
              for (int i = 0; i < children.length; i += 2) {
                final isLastRow = (i + 2 >= children.length);
                if (i + 1 < children.length) {
                  rows.add(
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: children[i]),
                          VerticalDivider(width: 1, thickness: 1, color: colors.outline.withOpacity(0.1)),
                          Expanded(child: children[i + 1]),
                        ],
                      ),
                    ),
                  );
                } else {
                  rows.add(children[i]);
                }
                
                if (!isLastRow) {
                  rows.add(Divider(height: 1, thickness: 1, color: colors.outline.withOpacity(0.1)));
                }
              }
              return Column(children: rows);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMappingRow(
    String label,
    String actionKey,
    IconData icon,
    MidiProfile activeProfile,
    MidiState state,
    MidiNotifier notifier,
    ColorScheme colors,
  ) {
    final mapping = activeProfile.mappings[actionKey];
    final isLearningThis = state.isLearning && state.learningAction == actionKey;

    String mappingText = 'Não mapeado';
    if (isLearningThis) {
      mappingText = 'Aguardando MIDI...';
    } else if (mapping != null) {
      mappingText = 'Sinal ${mapping.command} • N/CC ${mapping.noteOrCc}';
    }

    return InkWell(
      onTap: () { if (!isLearningThis) notifier.startLearning(actionKey); },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isLearningThis ? colors.primaryContainer : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: isLearningThis ? colors.onPrimaryContainer : colors.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
                      fontWeight: mapping != null ? FontWeight.bold : FontWeight.normal,
                      color: isLearningThis ? colors.primary : (mapping != null ? colors.onSurface : colors.onSurfaceVariant),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isLearningThis)
              FilledButton.tonal(
                onPressed: () => notifier.cancelLearning(),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.errorContainer,
                  foregroundColor: colors.onErrorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(50, 32),
                ),
                child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              )
            else
              OutlinedButton(
                onPressed: () => notifier.startLearning(actionKey),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: mapping != null ? colors.primary.withOpacity(0.5) : colors.outline),
                  foregroundColor: mapping != null ? colors.primary : colors.onSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(50, 32),
                ),
                child: Text(mapping != null ? 'REMAPEAR' : 'MAPEAR', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            if (mapping != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: colors.error,
                tooltip: 'Remover Mapeamento',
                onPressed: () {
                   notifier.removeMapping(actionKey);
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showNewProfileDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final colors = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceContainerHigh,
        title: const Text('Novo Perfil MIDI', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nome do Perfil (ex: Alesis Palco)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colors.surfaceContainerHighest,
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
