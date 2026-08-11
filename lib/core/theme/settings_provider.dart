// ignore_for_file: avoid_print
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prefs_sync_domain.dart';
import 'prefs_sync_state.dart';

// Provider global para acessar o SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

// Chaves para as configurações persistidas (definidas em PrefsSyncKeys)

class AppSettings {
  final double defaultFontSize;
  final String? customThemeColorHex;
  final String? customBgColorHex;
  final String? customTextColorHex;
  final String? customChordColorHex;
  final String? customLyricColorHex;
  final String? fontFamily;

  const AppSettings({
    this.defaultFontSize = 14.0, // Tamanho padrão razoável (Médio/Grande)
    this.customThemeColorHex,
    this.customBgColorHex,
    this.customTextColorHex,
    this.customChordColorHex,
    this.customLyricColorHex,
    this.fontFamily,
  });

  AppSettings copyWith({
    double? defaultFontSize,
    String? customThemeColorHex,
    String? customBgColorHex,
    String? customTextColorHex,
    String? customChordColorHex,
    String? customLyricColorHex,
    String? fontFamily,
  }) {
    return AppSettings(
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      customThemeColorHex: customThemeColorHex ?? this.customThemeColorHex,
      customBgColorHex: customBgColorHex ?? this.customBgColorHex,
      customTextColorHex: customTextColorHex ?? this.customTextColorHex,
      customChordColorHex: customChordColorHex ?? this.customChordColorHex,
      customLyricColorHex: customLyricColorHex ?? this.customLyricColorHex,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  late SharedPreferences _prefs;

  @override
  AppSettings build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      defaultFontSize: _prefs.getDouble(PrefsSyncKeys.fontSize) ?? 14.0,
      customThemeColorHex: _prefs.getString(PrefsSyncKeys.customThemeColor),
      customBgColorHex: _prefs.getString(PrefsSyncKeys.customBgColor),
      customTextColorHex: _prefs.getString(PrefsSyncKeys.customTextColor),
      customChordColorHex: _prefs.getString(PrefsSyncKeys.customChordColor),
      customLyricColorHex: _prefs.getString(PrefsSyncKeys.customLyricColor),
      fontFamily: _prefs.getString(PrefsSyncKeys.fontFamily),
    );
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(defaultFontSize: size);
    await _setDouble(PrefsSyncKeys.fontSize, size);
  }

  Future<void> setCustomThemeColorHex(String hex) async {
    state = state.copyWith(customThemeColorHex: hex);
    await _setString(PrefsSyncKeys.customThemeColor, hex);
  }

  Future<void> setCustomBgColorHex(String hex) async {
    state = state.copyWith(customBgColorHex: hex);
    await _setString(PrefsSyncKeys.customBgColor, hex);
  }

  Future<void> setCustomTextColorHex(String hex) async {
    state = state.copyWith(customTextColorHex: hex);
    await _setString(PrefsSyncKeys.customTextColor, hex);
  }

  Future<void> setCustomChordColorHex(String hex) async {
    state = state.copyWith(customChordColorHex: hex);
    await _setString(PrefsSyncKeys.customChordColor, hex);
  }

  Future<void> setCustomLyricColorHex(String hex) async {
    state = state.copyWith(customLyricColorHex: hex);
    await _setString(PrefsSyncKeys.customLyricColor, hex);
  }

  Future<void> setFontFamily(String font) async {
    state = state.copyWith(fontFamily: font);
    await _setString(PrefsSyncKeys.fontFamily, font);
  }

  Future<void> setViewMode(String mode) async {
    await _prefs.setString(PrefsSyncKeys.lastSongViewMode, mode);
    await _pushPrefs({PrefsSyncKeys.lastSongViewMode: mode});
  }

  Future<void> _setString(String key, String value) async {
    await _prefs.setString(key, value);
    await _pushPrefs({key: value});
  }

  Future<void> _setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
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

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});
