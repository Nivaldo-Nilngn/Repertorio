import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../songs/models/song.dart';
import '../../songs/repositories/song_repository.dart';
import '../providers/manager_providers.dart';
import '../providers/editor_provider.dart';

class ArtistProfileWorkspace extends ConsumerWidget {
  final String artist;

  const ArtistProfileWorkspace({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final songAsync = ref.watch(songListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            border: Border(bottom: BorderSide(color: colors.outline.withOpacity(0.2))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  ref.read(selectedArtistForViewProvider.notifier).state = null;
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  artist,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  ref.read(songFilterProvider.notifier).setArtist(artist);
                  ref.read(editingChordProProvider.notifier).state = '''{title: Nova Música}
{artist: $artist}
{key: C}
{tempo: 70}

{c: Verse 1}
Coloque sua [C]letra aqui
E os acordes [G]entre colchetes
''';
                  ref.read(selectedSongIdProvider.notifier).select(null);
                  ref.read(isEditorVisibleProvider.notifier).state = true;
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova Música'),
              ),
            ],
          ),
        ),
        
        // Body
        Expanded(
          child: songAsync.when(
            data: (songs) {
              final artistSongs = songs.where((s) => s.artist == artist).toList();
              
              if (artistSongs.isEmpty) {
                return const Center(child: Text('Nenhuma música encontrada para este artista.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: artistSongs.length,
                itemBuilder: (context, index) {
                  final song = artistSongs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(song.key, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10, fontFamily: 'Consolas')),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                          color: colors.surfaceContainer,
                          onSelected: (value) async {
                            if (value == 'edit') {
                              ref.read(songFilterProvider.notifier).setArtist(artist);
                              ref.read(selectedSongIdProvider.notifier).select(song.id);
                              ref.read(editingChordProProvider.notifier).state = song.content;
                              ref.read(isEditorVisibleProvider.notifier).state = true;
                            } else if (value == 'delete') {
                              _showDeleteDialog(context, ref, song, colors);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Excluir', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Song song, ColorScheme colors) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          title: const Text('Excluir Música'),
          content: Text('Tem certeza que deseja excluir "${song.title}"? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCELAR', style: TextStyle(color: colors.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              onPressed: () {
                ref.read(songRepositoryProvider).deleteSong(song.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Música excluída.'), backgroundColor: Colors.red),
                );
              },
              child: const Text('EXCLUIR'),
            ),
          ],
        );
      },
    );
  }
}
