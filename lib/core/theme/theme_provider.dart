// ignore_for_file: avoid_print
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'prefs_sync_domain.dart';
import 'prefs_sync_state.dart';
import 'settings_provider.dart';

class AppThemeNotifier extends Notifier<AppThemeType> {
  late SharedPreferences _prefs;

  @override
  AppThemeType build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final themeString = _prefs.getString(PrefsSyncKeys.themeType);

    if (themeString != null) {
      return AppThemeType.values.firstWhere(
        (e) => e.name == themeString,
        orElse: () => AppThemeType.managerDark,
      );
    }
    return AppThemeType.managerDark;
  }

  Future<void> setTheme(AppThemeType type) async {
    state = type;
    await _prefs.setString(PrefsSyncKeys.themeType, type.name);
    await _pushPrefs({PrefsSyncKeys.themeType: type.name});
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

final appThemeProvider = NotifierProvider<AppThemeNotifier, AppThemeType>(() {
  return AppThemeNotifier();
});