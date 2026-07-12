import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../songs/repositories/song_repository.dart';
import '../providers/manager_providers.dart';
import '../providers/editor_provider.dart';
import '../screens/artist_profile_workspace.dart';

class ArtistsWorkspace extends ConsumerStatefulWidget {
  const ArtistsWorkspace({super.key});

  @override
  ConsumerState<ArtistsWorkspace> createState() => _ArtistsWorkspaceState();
}

class _ArtistsWorkspaceState extends ConsumerState<ArtistsWorkspace> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final selectedArtist = ref.watch(selectedArtistForViewProvider);
    if (selectedArtist != null) {
      return ArtistProfileWorkspace(artist: selectedArtist);
    }

    final colors = Theme.of(context).colorScheme;
    final songAsync = ref.watch(songListProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(isMobile ? 16 : 32, isMobile ? 20 : 32, isMobile ? 16 : 32, isMobile ? 8 : 16),
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
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Buscar artista...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.outline.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ],
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
                  var artists = artistCounts.keys.toList()..sort();
                  
                  if (_searchQuery.isNotEmpty) {
                    artists = artists.where((a) => a.toLowerCase().contains(_searchQuery)).toList();
                  }

                  if (artists.isEmpty) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? 'Nenhum artista encontrado.' : 'Nenhum artista com músicas cadastradas.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
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
                            '${artists.length} ${_searchQuery.isNotEmpty ? "artistas encontrados" : "artistas no total"}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.extent(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 32,
                              vertical: isMobile ? 8 : 0,
                            ),
                            maxCrossAxisExtent: isMobile ? 180 : 220,
                            crossAxisSpacing: isMobile ? 10 : 20,
                            mainAxisSpacing: isMobile ? 10 : 20,
                            childAspectRatio: isMobile ? 0.85 : 0.9,
                            children: artists.map((artist) {
                              final count = artistCounts[artist] ?? 0;
                              return InkWell(
                                onTap: () {
                                  ref.read(selectedArtistForViewProvider.notifier).state = artist;
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: EdgeInsets.all(isMobile ? 8 : 20),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: isMobile ? 56 : 80,
                                        height: isMobile ? 56 : 80,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [colors.primary, colors.primary.withOpacity(0.6)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.primary.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            artist.substring(0, 1).toUpperCase(),
                                            style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        artist,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 12 : 16,
                                          color: colors.onSurface,
                                          height: 1.1,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$count ${count == 1 ? "música" : "músicas"}',
                                          style: TextStyle(
                                            color: colors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 10 : 12,
                                          ),
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
