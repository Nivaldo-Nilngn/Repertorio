// ignore_for_file: avoid_print
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/manager/providers/manager_providers.dart';
import 'prefs_sync_domain.dart';
import 'prefs_sync_state.dart';
import 'settings_provider.dart';
import 'theme_provider.dart';

// ---- Coordinator: puxa/planta as preferências remotas no login ----

final userSettingsSyncCoordinatorProvider =
    Provider<UserSettingsSyncCoordinator>((ref) {
  final coordinator = UserSettingsSyncCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class UserSettingsSyncCoordinator {
  final Ref _ref;

  /// Geração do pull atual. Incrementa a cada troca de auth para
  /// descartar pulls obsoletos (logout/login rápido durante um await).
  int _generation = 0;

  UserSettingsSyncCoordinator(this._ref) {
    _ref.listen(authStateProvider, (prev, next) {
      _handleAuthChange(next.value?.uid);
    });
  }

  void _handleAuthChange(String? uid) {
    if (uid == null) {
      // Deslogado: desliga a flag; prefs locais permanecem intactos.
      _ref.read(prefsSyncActiveProvider.notifier).end();
      _generation++;
      return;
    }
    _syncForUser(uid);
  }

  /// Verdadeiro se esta geração ainda é a atual e o usuário não mudou
  /// durante um await (logout/login rápido durante o pull).
  bool _isCurrent(String uid, int gen) {
    return gen == _generation && _ref.read(currentUserIdProvider) == uid;
  }

  void dispose() {}

  Future<void> _syncForUser(String uid) async {
    final gen = ++_generation;

    _ref.read(prefsSyncActiveProvider.notifier).begin(uid);
    final prefs = _ref.read(sharedPreferencesProvider);
    final service = _ref.read(userSettingsSyncServiceProvider);

    final remote = await service.loadPrefs();
    if (!_isCurrent(uid, gen)) return;

    if (remote.isEmpty) {
      // 1º login (ou nuvem sem prefs): sobe as locais como seed.
      await _seedFromLocal(uid);
      return;
    }

    // Nuvem vence: aplica as chaves remotas direto no SharedPreferences
    // (nunca pelos setters, para não disparar push).
    for (final key in PrefsSyncKeys.all) {
      final value = remote[key];
      if (value == null) continue;
      try {
        switch (key) {
          case PrefsSyncKeys.themeType:
          case PrefsSyncKeys.customThemeColor:
          case PrefsSyncKeys.customBgColor:
          case PrefsSyncKeys.customTextColor:
          case PrefsSyncKeys.customChordColor:
          case PrefsSyncKeys.customLyricColor:
          case PrefsSyncKeys.fontFamily:
          case PrefsSyncKeys.lastSongViewMode:
            await prefs.setString(key, value.toString());
          case PrefsSyncKeys.fontSize:
            await prefs.setDouble(key, (value as num).toDouble());
          case PrefsSyncKeys.isTopMenu:
            await prefs.setBool(key, value as bool);
          case PrefsSyncKeys.pinnedArtists:
            if (value is List) {
              await prefs.setStringList(
                  key, value.map((e) => e.toString()).toList());
            }
        }
      } catch (e) {
        print('Erro ao aplicar prefs remotas ($key): $e');
      }
    }

    // Migração: usuários antigos têm last_song_view_mode fora de /prefs.
    if (remote[PrefsSyncKeys.lastSongViewMode] == null) {
      final legacy = await service.readLegacyViewMode();
      if (legacy != null) {
        await prefs.setString(PrefsSyncKeys.lastSongViewMode, legacy);
        try {
          await service.writePrefs({PrefsSyncKeys.lastSongViewMode: legacy});
        } catch (_) {}
      }
    }

    if (!_isCurrent(uid, gen)) return;

    // Rebuild dos 4 providers a partir do SharedPreferences já atualizado.
    _ref.invalidate(prefsSyncActiveProvider);
    _ref.invalidate(appThemeProvider);
    _ref.invalidate(settingsProvider);
    _ref.invalidate(isTopMenuProvider);
    _ref.invalidate(pinnedArtistsProvider);

    _ref.read(prefsSyncActiveProvider.notifier).end();
  }

  Future<void> _seedFromLocal(String uid) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final map = <String, dynamic>{};

    map[PrefsSyncKeys.themeType] =
        prefs.getString(PrefsSyncKeys.themeType) ?? 'managerDark';
    map[PrefsSyncKeys.fontSize] =
        prefs.getDouble(PrefsSyncKeys.fontSize) ?? 14.0;
    map[PrefsSyncKeys.customThemeColor] =
        prefs.getString(PrefsSyncKeys.customThemeColor);
    map[PrefsSyncKeys.customBgColor] =
        prefs.getString(PrefsSyncKeys.customBgColor);
    map[PrefsSyncKeys.customTextColor] =
        prefs.getString(PrefsSyncKeys.customTextColor);
    map[PrefsSyncKeys.customChordColor] =
        prefs.getString(PrefsSyncKeys.customChordColor);
    map[PrefsSyncKeys.customLyricColor] =
        prefs.getString(PrefsSyncKeys.customLyricColor);
    map[PrefsSyncKeys.fontFamily] = prefs.getString(PrefsSyncKeys.fontFamily);
    map[PrefsSyncKeys.lastSongViewMode] =
        prefs.getString(PrefsSyncKeys.lastSongViewMode);
    map[PrefsSyncKeys.isTopMenu] =
        prefs.getBool(PrefsSyncKeys.isTopMenu) ?? false;
    map[PrefsSyncKeys.pinnedArtists] =
        prefs.getStringList(PrefsSyncKeys.pinnedArtists) ?? [];

    await _ref.read(userSettingsSyncServiceProvider).seedPrefs(map);
    // Local já é autoridade nesta rodada; não precisa recriar providers.
    _ref.read(prefsSyncActiveProvider.notifier).end();
  }
}