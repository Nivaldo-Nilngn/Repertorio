import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../songs/repositories/song_repository.dart';
import '../providers/manager_providers.dart';

class ArtistsWorkspace extends ConsumerStatefulWidget {
  const ArtistsWorkspace({super.key});
  @override
  ConsumerState<ArtistsWorkspace> createState() => _ArtistsWorkspaceState();
}

class _ArtistsWorkspaceState extends ConsumerState<ArtistsWorkspace> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final songAsync = ref.watch(songListProvider);
    final pinnedArtists = ref.watch(pinnedArtistsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 32,
                  isMobile ? 20 : 32,
                  isMobile ? 16 : 32,
                  isMobile ? 8 : 16,
                ),
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artistas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 20 : 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Buscar artista...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colors.outline.withOpacity(0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: colors.outline.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Content
              songAsync.when(
                data: (songs) {
                  // Group songs by artist
                  final Map<String, int> artistCounts = {};
                  for (final song in songs) {
                    final artistName = song.artist.trim().isEmpty
                        ? 'Artista Desconhecido'
                        : song.artist.trim();
                    artistCounts[artistName] =
                        (artistCounts[artistName] ?? 0) + 1;
                  }

                  var allArtists = artistCounts.keys.toList()..sort();
                  if (_searchQuery.isNotEmpty) {
                    allArtists = allArtists
                        .where((a) => a.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  if (allArtists.isEmpty) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Nenhum artista encontrado.'
                              : 'Nenhum artista com músicas cadastradas.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    );
                  }

                  final pinnedList = pinnedArtists
                      .where((a) => allArtists.contains(a))
                      .toList();
                  final otherList = allArtists
                      .where((a) => !pinnedArtists.contains(a))
                      .toList();

                  if (isMobile) {
                    return Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pinnedList.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Fixados',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100, // height of cards + padding
                              child: ReorderableListView.builder(
                                scrollDirection: Axis.horizontal,
                                buildDefaultDragHandles: false,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: pinnedList.length,
                                onReorder: (oldIndex, newIndex) {
                                  ref
                                      .read(pinnedArtistsProvider.notifier)
                                      .reorder(oldIndex, newIndex);
                                },
                                itemBuilder: (context, index) {
                                  return ReorderableDelayedDragStartListener(
                                    key: ValueKey(pinnedList[index]),
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: SizedBox(
                                        width: 250,
                                        child: _buildArtistCard(
                                          pinnedList[index],
                                          artistCounts[pinnedList[index]] ?? 0,
                                          true,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${otherList.length} ${pinnedList.isNotEmpty ? "outros artistas" : "artistas no total"}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildArtistGrid(
                              otherList,
                              artistCounts,
                              true,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Desktop Layout
                    return Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Sidebar for Pinned Artists
                          if (pinnedList.isNotEmpty)
                            Container(
                              width: 300,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainer,
                                border: Border(
                                  right: BorderSide(
                                    color: colors.outline.withOpacity(0.2),
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.push_pin,
                                          size: 20,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Fixados',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colors.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ReorderableListView.builder(
                                      buildDefaultDragHandles: false,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      itemCount: pinnedList.length,
                                      onReorder: (oldIndex, newIndex) {
                                        ref
                                            .read(
                                              pinnedArtistsProvider.notifier,
                                            )
                                            .reorder(oldIndex, newIndex);
                                      },
                                      itemBuilder: (context, index) {
                                        return ReorderableDragStartListener(
                                          key: ValueKey(pinnedList[index]),
                                          index: index,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: _buildArtistCard(
                                              pinnedList[index],
                                              artistCounts[pinnedList[index]] ??
                                                  0,
                                              true,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Main Grid
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  child: Text(
                                    '${otherList.length} ${pinnedList.isNotEmpty ? "outros artistas" : "artistas no total"}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _buildArtistGrid(
                                    otherList,
                                    artistCounts,
                                    false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
                loading: () => const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) =>
                    Expanded(child: Center(child: Text('Erro: $err'))),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistGrid(
    List<String> artists,
    Map<String, int> artistCounts,
    bool isMobile,
  ) {
    if (artists.isEmpty) {
      return Center(
        child: Text(
          'Nenhum artista nesta seção.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 8 : 16,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        crossAxisSpacing: isMobile ? 12 : 24,
        mainAxisSpacing: isMobile ? 12 : 24,
        mainAxisExtent: 80, // Fixed height for horizontal cards
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final count = artistCounts[artist] ?? 0;
        final isPinned = ref.watch(pinnedArtistsProvider).contains(artist);
        return _buildArtistCard(artist, count, isPinned);
      },
    );
  }

  Widget _buildArtistCard(String artist, int count, bool isPinned) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        ref.read(songFilterProvider.notifier).setArtist(artist);
        ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primary.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  artist.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count ${count == 1 ? "música" : "músicas"}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: isPinned
                    ? colors.primary
                    : colors.onSurfaceVariant.withOpacity(0.5),
              ),
              onPressed: () {
                ref.read(pinnedArtistsProvider.notifier).toggle(artist);
              },
              tooltip: isPinned ? 'Desfixar' : 'Fixar',
            ),
          ],
        ),
      ),
    );
  }
}
