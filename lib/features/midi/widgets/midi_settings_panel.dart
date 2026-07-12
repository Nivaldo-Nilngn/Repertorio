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

    if (!state.isSupported) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
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

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP BAR
          Row(
            children: [
              Icon(Icons.piano, color: colors.primary, size: 28),
              const SizedBox(width: 12),
              const Text('Controles MIDI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const Spacer(),
              
              // PANIC BUTTON
              FilledButton.icon(
                onPressed: state.activeOutputId != null ? () => notifier.triggerPanic() : null,
                icon: const Icon(Icons.warning_amber_rounded, size: 20),
                label: const Text('Panic (Silenciar)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: colors.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 16),

              // STATUS INDICATOR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: state.inputs.isNotEmpty ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: state.inputs.isNotEmpty ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
            ],
          ),
          const SizedBox(height: 32),
          
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN (Configuration)
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(24),
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
                                  width: 140,
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              onPressed: () => _showNewProfileDialog(context, ref),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDropdown<String>(
                          value: state.activeProfileId,
                          items: state.profiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                          onChanged: (val) { if (val != null) notifier.setActiveProfile(val); },
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // RIGHT COLUMN (Mappings List)
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outline.withOpacity(0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Ações Mapeáveis', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 20)),
                            Text('Clique em MAPEAR e pressione o botão no seu controlador.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                            const SizedBox(height: 24),
                            
                            _buildSectionTitle('Navegação de Repertório', Icons.library_music, colors),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildMappingRow('Próxima Música', 'next_song', Icons.skip_next, activeProfile, state, notifier, colors),
                                _buildMappingRow('Música Anterior', 'prev_song', Icons.skip_previous, activeProfile, state, notifier, colors),
                              ],
                            ),
                            const SizedBox(height: 24),
        
                            _buildSectionTitle('Controle de Rolagem', Icons.swap_vert, colors),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildMappingRow('Iniciar/Pausar Rolagem', 'toggle_scroll', Icons.play_arrow, activeProfile, state, notifier, colors),
                                _buildMappingRow('Aumentar Velocidade', 'speed_up', Icons.fast_forward, activeProfile, state, notifier, colors),
                                _buildMappingRow('Diminuir Velocidade', 'speed_down', Icons.fast_rewind, activeProfile, state, notifier, colors),
                                _buildMappingRow('Página p/ Baixo', 'scroll_down', Icons.arrow_downward, activeProfile, state, notifier, colors),
                                _buildMappingRow('Página p/ Cima', 'scroll_up', Icons.arrow_upward, activeProfile, state, notifier, colors),
                              ],
                            ),
                            const SizedBox(height: 24),
        
                            _buildSectionTitle('Tonalidade (Transposição)', Icons.music_note, colors),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildMappingRow('Subir Tom (+)', 'tone_up', Icons.arrow_drop_up, activeProfile, state, notifier, colors),
                                _buildMappingRow('Descer Tom (-)', 'tone_down', Icons.arrow_drop_down, activeProfile, state, notifier, colors),
                              ],
                            ),
                            const SizedBox(height: 24),

                            _buildSectionTitle('Performance & Mixer', Icons.tune, colors),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildMappingRow('Volume Geral', 'volume_master', Icons.volume_up, activeProfile, state, notifier, colors),
                                _buildMappingRow('Mute (Cortar Som)', 'mute_toggle', Icons.volume_off, activeProfile, state, notifier, colors),
                                _buildMappingRow('Trocar Timbre', 'patch_change', Icons.piano, activeProfile, state, notifier, colors),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Divider(color: colors.outline.withOpacity(0.2))),
        ],
      ),
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

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isLearningThis ? colors.primaryContainer.withOpacity(0.3) : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLearningThis ? colors.primary : colors.outline.withOpacity(0.15),
          width: isLearningThis ? 2.0 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: isLearningThis ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isLearningThis ? colors.primary : colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLearningThis ? colors.primary.withOpacity(0.1) : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    mappingText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: mapping != null ? FontWeight.bold : FontWeight.normal,
                      color: isLearningThis 
                          ? colors.primary 
                          : mapping != null ? colors.onSurface : colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                    side: BorderSide(color: mapping != null ? colors.primary.withOpacity(0.5) : colors.outline),
                    foregroundColor: mapping != null ? colors.primary : colors.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(60, 32),
                  ),
                  child: Text(mapping != null ? 'REMAPEAR' : 'MAPEAR', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
            ],
          ),
        ],
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
