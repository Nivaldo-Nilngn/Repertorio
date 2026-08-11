// ignore_for_file: avoid_print
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/prefs_sync_domain.dart';
import '../../../core/theme/prefs_sync_state.dart';
import '../../../core/theme/settings_provider.dart';
import '../../songs/models/song_setlist.dart';

enum SidebarTab { songs, prepare, artists, favorites, settings }

class SongFilter {
  final String? folderId;
  final String? artist;
  final String? tag;
  final bool onlyFavorites;

  const SongFilter({
    this.folderId,
    this.artist,
    this.tag,
    this.onlyFavorites = false,
  });

  SongFilter copyWith({
    String? folderId,
    String? artist,
    String? tag,
    bool? onlyFavorites,
  }) {
    return SongFilter(
      folderId: folderId,
      artist: artist,
      tag: tag ?? this.tag,
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
    );
  }

  bool get isEmpty =>
      folderId == null && artist == null && tag == null && !onlyFavorites;
}

class SongFilterNotifier extends Notifier<SongFilter> {
  bool _hasInitializedUpcoming = false;

  @override
  SongFilter build() => const SongFilter();

  void initializeWithUpcoming(List<SongSetlist> setlists) {
    if (_hasInitializedUpcoming || setlists.isEmpty) return;
    _hasInitializedUpcoming = true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    SongSetlist? closestSetlist;
    int? minDiff;

    for (final setlist in setlists) {
      final dateStr = setlist.date;
      final parsedDate = _parseDate(dateStr);
      if (parsedDate != null) {
        final diff = parsedDate.difference(today).inDays;
        if (diff >= 0) {
          if (minDiff == null || diff < minDiff) {
            minDiff = diff;
            closestSetlist = setlist;
          }
        }
      }
    }

    if (closestSetlist != null) {
      // Keep onlyFavorites or artist filters if they were manually set before load,
      // but override folderId
      state = state.copyWith(folderId: closestSetlist.id);
    }
  }

  DateTime? _parseDate(String dateStr) {
    final regex = RegExp(r'^(\d+)\s+([a-zA-ZçÇ]+),\s+(\d+)$');
    final match = regex.firstMatch(dateStr.trim());
    if (match != null) {
      final day = int.tryParse(match.group(1)!);
      final monthStr = match.group(2)!.toLowerCase();
      final year = int.tryParse(match.group(3)!);

      final months = [
        'jan',
        'fev',
        'mar',
        'abr',
        'mai',
        'jun',
        'jul',
        'ago',
        'set',
        'out',
        'nov',
        'dez',
      ];
      final month = months.indexOf(monthStr) + 1;

      if (day != null && year != null && month > 0) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  void setFolder(String? folderId) {
    state = SongFilter(folderId: folderId);
  }

  void setArtist(String? artist) {
    state = SongFilter(artist: artist);
  }

  void setTag(String? tag) {
    state = SongFilter(tag: tag);
  }

  void setOnlyFavorites(bool onlyFavorites) {
    state = SongFilter(onlyFavorites: onlyFavorites);
  }

  void clear() {
    state = const SongFilter();
  }

  void clearExceptFolder() {
    state = SongFilter(
      folderId: state.folderId,
      artist: null,
      tag: null,
      onlyFavorites: false,
    );
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

class SelectedArtistNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? artist) {
    state = artist;
  }
}

final selectedArtistForViewProvider =
    NotifierProvider<SelectedArtistNotifier, String?>(() {
      return SelectedArtistNotifier();
    });

class IsTopMenuNotifier extends Notifier<bool> {
  late SharedPreferences _prefs;

  @override
  bool build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _prefs.getBool(PrefsSyncKeys.isTopMenu) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    await _setBool(PrefsSyncKeys.isTopMenu, state);
  }

  Future<void> _setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
    await _pushPrefs({key: value});
  }

  Future<void> _pushPrefs(Map<String, dynamic> values) async {
    final service = ref.read(userSettingsSyncServiceProvider);
    if (!service.isSignedIn) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!ref.read(prefsSyncActiveProvider).shouldPush(uid)) return;
    try {
      await service.writePrefs(values);
    } catch (e) {
      print('Erro ao salvar preferências no Firebase: $e');
    }
  }
}

final isTopMenuProvider = NotifierProvider<IsTopMenuNotifier, bool>(() {
  return IsTopMenuNotifier();
});

class PinnedArtistsNotifier extends Notifier<List<String>> {
  late SharedPreferences _prefs;

  @override
  List<String> build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _prefs.getStringList(PrefsSyncKeys.pinnedArtists) ?? [];
  }

  Future<void> toggle(String artist) async {
    final newState = List<String>.from(state);
    if (newState.contains(artist)) {
      newState.remove(artist);
    } else {
      newState.add(artist);
    }
    state = newState;
    await _persistPinned(newState);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newState = List<String>.from(state);
    final artist = newState.removeAt(oldIndex);
    newState.insert(newIndex, artist);
    state = newState;
    await _persistPinned(newState);
  }

  Future<void> _persistPinned(List<String> list) async {
    await _prefs.setStringList(PrefsSyncKeys.pinnedArtists, list);
    await _pushPrefs({PrefsSyncKeys.pinnedArtists: list});
  }

  Future<void> _pushPrefs(Map<String, dynamic> values) async {
    final service = ref.read(userSettingsSyncServiceProvider);
    if (!service.isSignedIn) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!ref.read(prefsSyncActiveProvider).shouldPush(uid)) return;
    try {
      await service.writePrefs(values);
    } catch (e) {
      print('Erro ao salvar preferências no Firebase: $e');
    }
  }
}

final pinnedArtistsProvider =
    NotifierProvider<PinnedArtistsNotifier, List<String>>(() {
      return PinnedArtistsNotifier();
    });
