import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../songs/models/song.dart';
import '../../songs/models/song_setlist.dart';
import '../../songs/repositories/song_repository.dart';
import '../providers/manager_providers.dart';
import '../providers/editor_provider.dart';

class ArrangeWorkspace extends ConsumerStatefulWidget {
  const ArrangeWorkspace({super.key});

  @override
  ConsumerState<ArrangeWorkspace> createState() => _ArrangeWorkspaceState();
}

class _ArrangeWorkspaceState extends ConsumerState<ArrangeWorkspace> {
  SongSetlist? _activeSetlist;
  String _searchQuery = '';
  bool _isDirty = false;

  void _showCreateSongDialog() {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    String selectedKey = 'C';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text('Nova Música'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título da Música'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: artistController,
                    decoration: const InputDecoration(labelText: 'Artista'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tom:'),
                      DropdownButton<String>(
                        value: selectedKey,
                        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        items: ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']
                            .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() {
                              selectedKey = v;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final artist = artistController.text.trim();
                    if (title.isEmpty) return;

                    final songId = title.toLowerCase().replaceAll(RegExp(r'[\s/.#\$\[\]]+'), '_');
                    final chordPro = '{title: $title}\n{artist: ${artist.isEmpty ? "Artista Desconhecido" : artist}}\n{key: $selectedKey}\n\n[C]Coloque os acordes e letra aqui...';

                    final newSong = Song(
                      id: songId,
                      title: title,
                      artist: artist.isEmpty ? "Artista Desconhecido" : artist,
                      key: selectedKey,
                      bpm: 0,
                      content: chordPro,
                    );

                    await ref.read(songRepositoryProvider).createSong(newSong);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Música adicionada à Biblioteca!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text('SALVAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateSetlistDialog() {
    final nameController = TextEditingController();
    final dateController = TextEditingController(text: "${DateTime.now().day} Out, ${DateTime.now().year}");
    bool initializeWithTemplate = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text('Novo Repertório'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome do Repertório'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(labelText: 'Data / Evento'),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Modelo de Culto Padrão', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Estrutura automática de louvor, avisos e pregação', style: TextStyle(fontSize: 11)),
                    value: initializeWithTemplate,
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          initializeWithTemplate = v;
                        });
                      }
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final date = dateController.text.trim();
                    if (name.isEmpty) return;

                    final id = FirebaseDatabase.instance.ref('setlists').push().key ?? DateTime.now().millisecondsSinceEpoch.toString();
                    
                    final List<SetlistItem> initialItems = [];
                    if (initializeWithTemplate) {
                      initialItems.addAll([
                        const SetlistItem(type: 'note', title: 'Celebração (Música 1)', subtitle: '4:00', duration: '4:00', colorHex: '#ffb95f'),
                        const SetlistItem(type: 'note', title: 'Celebração (Música 2)', subtitle: '4:00', duration: '4:00', colorHex: '#ffb95f'),
                        const SetlistItem(type: 'note', title: 'Adoração (Música 1)', subtitle: '4:00', duration: '4:00', colorHex: '#4edea3'),
                        const SetlistItem(type: 'note', title: 'Adoração (Música 2)', subtitle: '4:00', duration: '4:00', colorHex: '#4edea3'),
                        const SetlistItem(type: 'note', title: 'Avisos da Mídia', subtitle: '5:00', duration: '5:00', colorHex: '#adc6ff'),
                        const SetlistItem(type: 'note', title: 'Dízimos e Ofertas', subtitle: '4:00', duration: '4:00', colorHex: '#adc6ff'),
                        const SetlistItem(type: 'note', title: 'Chamada para Pregação (Música)', subtitle: '4:00', duration: '4:00', colorHex: '#b19ffb'),
                        const SetlistItem(type: 'note', title: 'Pregação (Mensagem)', subtitle: '30:00', duration: '30:00', colorHex: '#b19ffb'),
                        const SetlistItem(type: 'note', title: 'Encerramento (Música Opcional)', subtitle: '4:00', duration: '4:00', colorHex: '#ff8b8b'),
                      ]);
                    }

                    final newSetlist = SongSetlist(
                      id: id,
                      name: name,
                      date: date,
                      items: initialItems,
                    );

                    await ref.read(songRepositoryProvider).createSetlist(newSetlist);
                    setState(() {
                      _activeSetlist = newSetlist;
                      _isDirty = initializeWithTemplate;
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Repertório "$name" criado!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text('CRIAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addSongToSetlist(Song song) {
    if (_activeSetlist == null) return;

    final newItem = SetlistItem(
      type: 'song',
      title: song.title,
      subtitle: song.artist,
      key: song.key,
      duration: '4:00',
      colorHex: '#ffb95f',
    );

    final updatedItems = List<SetlistItem>.from(_activeSetlist!.items)..add(newItem);
    setState(() {
      _activeSetlist = _activeSetlist!.copyWith(items: updatedItems);
      _isDirty = true;
    });
  }

  void _addNoteToSetlist() {
    if (_activeSetlist == null) return;
    
    final noteController = TextEditingController();
    final durationController = TextEditingController(text: '3:00');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Adicionar Bloco/Aviso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Texto/Aviso/Momento'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duração estimada (ex: 3:00)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                final text = noteController.text.trim();
                final dur = durationController.text.trim();
                if (text.isEmpty) return;

                final newItem = SetlistItem(
                  type: 'note',
                  title: text,
                  subtitle: dur,
                  duration: dur,
                  colorHex: '#adc6ff',
                );

                final updatedItems = List<SetlistItem>.from(_activeSetlist!.items)..add(newItem);
                setState(() {
                  _activeSetlist = _activeSetlist!.copyWith(items: updatedItems);
                  _isDirty = true;
                });
                Navigator.pop(context);
              },
              child: const Text('ADICIONAR'),
            ),
          ],
        );
      },
    );
  }

  void _moveItem(int index, int delta) {
    if (_activeSetlist == null) return;
    final items = List<SetlistItem>.from(_activeSetlist!.items);
    final newIndex = index + delta;
    if (newIndex >= 0 && newIndex < items.length) {
      final temp = items[index];
      items[index] = items[newIndex];
      items[newIndex] = temp;
      setState(() {
        _activeSetlist = _activeSetlist!.copyWith(items: items);
        _isDirty = true;
      });
    }
  }

  void _deleteItem(int index) {
    if (_activeSetlist == null) return;
    final items = List<SetlistItem>.from(_activeSetlist!.items)..removeAt(index);
    setState(() {
      _activeSetlist = _activeSetlist!.copyWith(items: items);
      _isDirty = true;
    });
  }

  void _saveSetlistToFirebase() async {
    if (_activeSetlist == null) return;
    
    try {
      await ref.read(songRepositoryProvider).updateSetlist(_activeSetlist!);
      setState(() {
        _isDirty = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repertório salvo com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildColorPicker(int index, SetlistItem item, ColorScheme colors) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.palette_outlined, size: 18, color: colors.onSurfaceVariant),
      tooltip: 'Cor de Destaque',
      onSelected: (hex) {
        final items = List<SetlistItem>.from(_activeSetlist!.items);
        items[index] = items[index].copyWith(colorHex: hex);
        setState(() {
          _activeSetlist = _activeSetlist!.copyWith(items: items);
          _isDirty = true;
        });
      },
      itemBuilder: (context) => [
        _buildColorMenuItem('#ffb95f', 'Laranja (Celebração)', Colors.orange),
        _buildColorMenuItem('#4edea3', 'Verde (Adoração)', Colors.green),
        _buildColorMenuItem('#adc6ff', 'Azul (Mídia / Avisos)', Colors.blue),
        _buildColorMenuItem('#b19ffb', 'Roxo (Mensagem / Chamada)', Colors.purple),
        _buildColorMenuItem('#ff8b8b', 'Vermelho (Encerramento)', Colors.red),
      ],
    );
  }

  PopupMenuItem<String> _buildColorMenuItem(String hex, String name, Color color) {
    return PopupMenuItem<String>(
      value: hex,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDashboardView(List<SongSetlist> setlists, ColorScheme colors) {
    // Sort chronologically reverse (newest created at the top)
    final sortedSetlists = setlists.reversed.toList();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gerenciador de Repertórios',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Crie, edite ou exclua os roteiros de culto e eventos',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _showCreateSetlistDialog,
                icon: const Icon(Icons.add),
                label: const Text('NOVO REPERTÓRIO'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: sortedSetlists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_play, size: 64, color: colors.outline.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum repertório criado ainda.',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _showCreateSetlistDialog,
                          child: const Text('Criar Meu Primeiro Repertório'),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: sortedSetlists.length,
                    itemBuilder: (context, index) {
                      final setlist = sortedSetlists[index];
                      
                      // Calculate duration
                      int totalMinutes = 0;
                      int songCount = 0;
                      for (var item in setlist.items) {
                        if (item.type == 'song') {
                          totalMinutes += 4;
                          songCount++;
                        } else {
                          final digits = RegExp(r'(\d+)').firstMatch(item.duration);
                          if (digits != null) {
                            totalMinutes += int.parse(digits.group(1)!);
                          }
                        }
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF131b2e),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outline.withOpacity(0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                setlist.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: colors.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    setlist.date,
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$songCount músicas',
                                      style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Est. $totalMinutes min',
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _activeSetlist = setlist;
                                          _isDirty = false;
                                        });
                                      },
                                      child: const Text('Organizar Roteiro', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    color: Colors.redAccent.withOpacity(0.8),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: colors.surface,
                                          title: const Text('Excluir Repertório'),
                                          content: Text('Tem certeza que deseja excluir "${setlist.name}"?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('EXCLUIR'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await ref.read(songRepositoryProvider).deleteSetlist(setlist.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final songAsync = ref.watch(songListProvider);
    final setlistAsync = ref.watch(setlistListProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return setlistAsync.when(
          data: (setlists) {
            if (_activeSetlist == null) {
              return isMobile
                  ? _buildMobileDashboard(setlists, colors)
                  : _buildDashboardView(setlists, colors);
            }

            // Sync with active setlist
            final matchedSetlist = setlists.where((s) => s.id == _activeSetlist!.id).firstOrNull;
            if (matchedSetlist == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _activeSetlist = null;
                  _isDirty = false;
                });
              });
              return isMobile
                  ? _buildMobileDashboard(setlists, colors)
                  : _buildDashboardView(setlists, colors);
            }

            if (_activeSetlist != matchedSetlist && !_isDirty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _activeSetlist = matchedSetlist;
                });
              });
            }

            if (isMobile) {
              return _buildMobileEditorView(songAsync, colors);
            }

            return Row(
              children: [
                // Left Column: Biblioteca list of songs
                Container(
                  width: 400,
                  color: const Color(0xFF060e20),
                  child: _buildBibliotecaView(songAsync, colors),
                ),
                Container(width: 1, color: colors.outline.withOpacity(0.4)),

                // Right Column: Active Setlist Details Canvas
                Expanded(
                  child: Container(
                    color: colors.surface,
                    child: _buildSetlistCanvas(colors),
                  ),
                ),
              ],
            );
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Erro: $err'))),
        );
      },
    );
  }

  // ─── MOBILE DASHBOARD ────────────────────────────────────────────────────────

  Widget _buildMobileDashboard(List<SongSetlist> setlists, ColorScheme colors) {
    final sortedSetlists = setlists.reversed.toList();
    return Container(
      color: const Color(0xFF0A0F1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            color: const Color(0xFF171f33),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Repertórios',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                FilledButton.icon(
                  onPressed: _showCreateSetlistDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Novo'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sortedSetlists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_play, size: 64, color: colors.outline.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('Nenhum repertório criado ainda.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _showCreateSetlistDialog,
                          child: const Text('Criar Meu Primeiro Repertório'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sortedSetlists.length,
                    itemBuilder: (context, index) {
                      final setlist = sortedSetlists[index];
                      int totalMinutes = 0;
                      int songCount = 0;
                      for (var item in setlist.items) {
                        if (item.type == 'song') {
                          totalMinutes += 4;
                          songCount++;
                        } else {
                          final digits = RegExp(r'(\d+)').firstMatch(item.duration);
                          if (digits != null) totalMinutes += int.parse(digits.group(1)!);
                        }
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131b2e),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outline.withOpacity(0.2)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            setlist.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: colors.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(setlist.date, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('$songCount músicas',
                                        style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Est. $totalMinutes min',
                                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: Colors.redAccent.withOpacity(0.8),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: colors.surface,
                                      title: const Text('Excluir Repertório'),
                                      content: Text('Excluir "${setlist.name}"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('EXCLUIR'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await ref.read(songRepositoryProvider).deleteSetlist(setlist.id);
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.arrow_forward_ios, size: 16, color: colors.primary),
                                onPressed: () {
                                  setState(() {
                                    _activeSetlist = setlist;
                                    _isDirty = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── MOBILE EDITOR VIEW (tabs: Roteiro | Biblioteca) ─────────────────────────

  Widget _buildMobileEditorView(AsyncValue<List<Song>> songAsync, ColorScheme colors) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Header
          Container(
            color: const Color(0xFF171f33),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() {
                          _activeSetlist = null;
                          _isDirty = false;
                        }),
                      ),
                      Expanded(
                        child: Text(
                          _activeSetlist!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isDirty)
                        TextButton.icon(
                          onPressed: _saveSetlistToFirebase,
                          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                          label: const Text('SALVAR'),
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: colors.secondary, size: 16),
                            const SizedBox(width: 4),
                            Text('SALVO', style: TextStyle(color: colors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: const [
                    Tab(icon: Icon(Icons.list, size: 18), text: 'Roteiro'),
                    Tab(icon: Icon(Icons.library_music, size: 18), text: 'Biblioteca'),
                  ],
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.onSurfaceVariant,
                  indicatorColor: colors.primary,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Setlist canvas
                Container(
                  color: colors.surface,
                  child: _buildMobileSetlistCanvas(colors),
                ),
                // Tab 2: Biblioteca
                Container(
                  color: const Color(0xFF060e20),
                  child: _buildBibliotecaView(songAsync, colors),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSetlistCanvas(ColorScheme colors) {
    int totalMinutes = 0;
    for (var item in _activeSetlist!.items) {
      if (item.type == 'song') {
        totalMinutes += 4;
      } else {
        final digits = RegExp(r'(\d+)').firstMatch(item.duration);
        if (digits != null) totalMinutes += int.parse(digits.group(1)!);
      }
    }
    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('Est. $totalMinutes min',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addNoteToSetlist,
                icon: const Icon(Icons.note_add, size: 16),
                label: const Text('Bloco', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _activeSetlist!.items.isEmpty
              ? Center(
                  child: Text(
                    'Vazio.\nAdicione músicas na aba Biblioteca!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: _activeSetlist!.items.length,
                  itemBuilder: (context, index) {
                    final item = _activeSetlist!.items[index];
                    return item.type == 'song'
                        ? _buildSetlistSongItem(index, item, colors)
                        : _buildSetlistNoteItem(index, item, colors);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBibliotecaView(AsyncValue<List<Song>> songAsync, ColorScheme colors) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Biblioteca', style: Theme.of(context).textTheme.titleLarge),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2d3449),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: songAsync.when(
                      data: (songs) => Text('${songs.length} músicas', style: const TextStyle(fontSize: 10)),
                      loading: () => const Text('...', style: TextStyle(fontSize: 10)),
                      error: (_, __) => const Text('Erro', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar músicas, artistas...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.outline),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: colors.outline.withOpacity(0.3), height: 1),
        Expanded(
          child: songAsync.when(
            data: (songs) {
              final filteredSongs = songs.where((s) {
                final query = _searchQuery.trim();
                if (query.isEmpty) return true;
                return s.title.toLowerCase().contains(query) || s.artist.toLowerCase().contains(query);
              }).toList();

              if (filteredSongs.isEmpty) {
                return const Center(child: Text('Nenhuma música encontrada.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredSongs.length,
                itemBuilder: (context, index) {
                  final song = filteredSongs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131b2e),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.outline.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(song.artist, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2d3449),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(song.key, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10, fontFamily: 'Consolas')),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, size: 20),
                          color: colors.primary,
                          onPressed: () => _addSongToSetlist(song),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erro: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildSetlistCanvas(ColorScheme colors) {
    // Calculate total duration
    int totalMinutes = 0;
    for (var item in _activeSetlist!.items) {
      if (item.type == 'song') {
        totalMinutes += 4;
      } else {
        final digits = RegExp(r'(\d+)').firstMatch(item.duration);
        if (digits != null) {
          totalMinutes += int.parse(digits.group(1)!);
        }
      }
    }

    return Column(
      children: [
        // Setlist Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outline.withOpacity(0.2))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Voltar para a Lista',
                    onPressed: () {
                      setState(() {
                        _activeSetlist = null;
                        _isDirty = false;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_activeSetlist!.name, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(_activeSetlist!.date, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(width: 16),
                          Icon(Icons.schedule, size: 16, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('Est. $totalMinutes min', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  if (_isDirty)
                    FilledButton.icon(
                      onPressed: _saveSetlistToFirebase,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('SALVAR REPERTÓRIO'),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: colors.secondary),
                        const SizedBox(width: 8),
                        Text('SALVO', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 13)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        // Builder Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  border: Border.all(color: colors.outline.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildToolbarButton(Icons.note_add, 'Adicionar Bloco/Aviso', _addNoteToSetlist, colors),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Canvas list items
        Expanded(
          child: _activeSetlist!.items.isEmpty
              ? Center(
                  child: Text(
                    'Este repertório está vazio.\nAdicione músicas a partir da aba Biblioteca ao lado!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _activeSetlist!.items.length,
                  itemBuilder: (context, index) {
                    final item = _activeSetlist!.items[index];
                    if (item.type == 'song') {
                      return _buildSetlistSongItem(index, item, colors);
                    } else {
                      return _buildSetlistNoteItem(index, item, colors);
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildToolbarButton(IconData icon, String label, VoidCallback onPressed, ColorScheme colors) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: colors.onSurfaceVariant),
      label: Text(label, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSetlistSongItem(int index, SetlistItem item, ColorScheme colors) {
    final stripColor = item.colorHex != null ? Color(int.parse(item.colorHex!.replaceFirst('#', '0xFF'))) : const Color(0xFFffb95f);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withOpacity(0.3)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: stripColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    onPressed: index > 0 ? () => _moveItem(index, -1) : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 4),
                  Text('${index + 1}', style: TextStyle(color: colors.onSurfaceVariant.withOpacity(0.5), fontFamily: 'Consolas', fontSize: 13)),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    onPressed: index < _activeSetlist!.items.length - 1 ? () => _moveItem(index, 1) : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(item.subtitle, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF060e20),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.outline.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Text('Tom ', style: TextStyle(color: Color(0xFFffb95f), fontFamily: 'Consolas', fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(item.key.isEmpty ? 'C' : item.key, style: const TextStyle(fontFamily: 'Consolas', fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note, size: 22),
              color: colors.primary,
              tooltip: 'Editar Música',
              onPressed: () {
                final songs = ref.read(songListProvider).value ?? [];
                try {
                  final matchingSong = songs.firstWhere((s) => s.title == item.title);
                  ref.read(editingChordProProvider.notifier).state = matchingSong.content;
                  ref.read(isEditorVisibleProvider.notifier).state = true;
                  ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
                  ref.read(songFilterProvider.notifier).clear();
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cifra não encontrada na Biblioteca!'), backgroundColor: Colors.orange),
                  );
                }
              },
            ),
            _buildColorPicker(index, item, colors),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
              onPressed: () => _deleteItem(index),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSetlistNoteItem(int index, SetlistItem item, ColorScheme colors) {
    final stripColor = item.colorHex != null ? Color(int.parse(item.colorHex!.replaceFirst('#', '0xFF'))) : colors.outline.withOpacity(0.5);
    return Container(
      margin: const EdgeInsets.only(left: 32, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131b2e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outline.withOpacity(0.3)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: stripColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chat_bubble_outline, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  item.title,
                  style: TextStyle(color: colors.onSurfaceVariant, fontStyle: FontStyle.italic),
                ),
              ),
            ),
            Text(
              item.duration,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 16),
              onPressed: index > 0 ? () => _moveItem(index, -1) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 16),
              onPressed: index < _activeSetlist!.items.length - 1 ? () => _moveItem(index, 1) : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            _buildColorPicker(index, item, colors),
            IconButton(
              icon: const Icon(Icons.delete, size: 16),
              color: Colors.redAccent.withOpacity(0.8),
              onPressed: () => _deleteItem(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
