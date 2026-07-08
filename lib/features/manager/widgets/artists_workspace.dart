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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          color: const Color(0xFF0A0F1E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(isMobile ? 16 : 32, isMobile ? 20 : 32, isMobile ? 16 : 32, isMobile ? 8 : 8),
                color: const Color(0xFF171f33),
                child: Text(
                  'Artistas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 20 : 32,
                      ),
                ),
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
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                          child: Text(
                            '${artists.length} artistas no total',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.extent(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 32,
                              vertical: isMobile ? 8 : 0,
                            ),
                            maxCrossAxisExtent: isMobile ? 180 : 240,
                            crossAxisSpacing: isMobile ? 10 : 16,
                            mainAxisSpacing: isMobile ? 10 : 16,
                            childAspectRatio: isMobile ? 1.0 : 1.1,
                            children: artists.map((artist) {
                              final count = artistCounts[artist] ?? 0;
                              return InkWell(
                                onTap: () {
                                  ref.read(songFilterProvider.notifier).setArtist(artist);
                                  ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131b2e),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colors.outline.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: isMobile ? 34 : 40,
                                        height: isMobile ? 34 : 40,
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: colors.outline),
                                        ),
                                        child: Icon(Icons.person, color: colors.primary, size: isMobile ? 20 : 24),
                                      ),
                                      const Spacer(),
                                      Text(
                                        artist,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 13 : 16,
                                          color: Colors.white,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$count ${count == 1 ? "música" : "músicas"}',
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: isMobile ? 11 : 12,
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
      },
    );
  }
}
