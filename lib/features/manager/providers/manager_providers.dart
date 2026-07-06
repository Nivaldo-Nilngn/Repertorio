import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SidebarTab { songs, prepare, artists, favorites }

class SongFilter {
  final String? folderId;
  final String? artist;
  final bool onlyFavorites;

  const SongFilter({
    this.folderId,
    this.artist,
    this.onlyFavorites = false,
  });

  SongFilter copyWith({
    String? folderId,
    String? artist,
    bool? onlyFavorites,
  }) {
    return SongFilter(
      folderId: folderId,
      artist: artist,
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
    );
  }

  bool get isEmpty => folderId == null && artist == null && !onlyFavorites;
}

class SongFilterNotifier extends Notifier<SongFilter> {
  @override
  SongFilter build() => const SongFilter();

  void setFolder(String? folderId) {
    state = SongFilter(folderId: folderId);
  }

  void setArtist(String? artist) {
    state = SongFilter(artist: artist);
  }

  void setOnlyFavorites(bool onlyFavorites) {
    state = SongFilter(onlyFavorites: onlyFavorites);
  }

  void clear() {
    state = const SongFilter();
  }
}

final songFilterProvider = NotifierProvider<SongFilterNotifier, SongFilter>(() {
  return SongFilterNotifier();
});

class SidebarTabNotifier extends Notifier<SidebarTab> {
  @override
  SidebarTab build() => SidebarTab.songs;

  void setTab(SidebarTab tab) {
    state = tab;
  }
}

final sidebarTabProvider = NotifierProvider<SidebarTabNotifier, SidebarTab>(() {
  return SidebarTabNotifier();
});
