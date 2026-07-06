import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../songs/repositories/song_repository.dart';
import '../providers/manager_providers.dart';

class ArtistsWorkspace extends ConsumerWidget {
  const ArtistsWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final songAsync = ref.watch(songListProvider);

    return Container(
      color: const Color(0xFF171f33), // surface container matching others
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Artistas',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          songAsync.when(
            data: (songs) {
              // Group songs by artist
              final Map<String, int> artistCounts = {};
              for (final song in songs) {
                final artistName = song.artist.trim().isEmpty ? 'Artista Desconhecido' : song.artist.trim();
                artistCounts[artistName] = (artistCounts[artistName] ?? 0) + 1;
              }
              final artists = artistCounts.keys.toList()..sort();

              if (artists.isEmpty) {
                return const Expanded(
                  child: Center(
                    child: Text('Nenhum artista com músicas cadastradas.'),
                  ),
                );
              }

              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${artists.length} artistas no total',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.extent(
                        maxCrossAxisExtent: 240,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: artists.map((artist) {
                          final count = artistCounts[artist] ?? 0;
                          return InkWell(
                            onTap: () {
                              ref.read(songFilterProvider.notifier).setArtist(artist);
                              ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF31394d),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.outline.withOpacity(0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colors.outline),
                                    ),
                                    child: Icon(Icons.person, color: colors.primary, size: 24),
                                  ),
                                  const Spacer(),
                                  Text(
                                    artist,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$count ${count == 1 ? "música" : "músicas"}',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, stack) => Expanded(
              child: Center(
                child: Text('Erro: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
