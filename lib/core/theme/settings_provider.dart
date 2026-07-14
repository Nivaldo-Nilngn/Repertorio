import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider global para acessar o SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main.dart');
});

// Chaves para as configurações persistidas
const _kThemeKey = 'theme_type';
const _kCustomThemeColorKey = 'custom_theme_color';
const _kCustomBgColorKey = 'custom_bg_color';
const _kCustomTextColorKey = 'custom_text_color';
const _kCustomChordColorKey = 'custom_chord_color';
const _kCustomLyricColorKey = 'custom_lyric_color';
const _kFontSizeKey = 'default_font_size';
const _kFontFamilyKey = 'font_family';

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
      defaultFontSize: _prefs.getDouble(_kFontSizeKey) ?? 14.0,
      customThemeColorHex: _prefs.getString(_kCustomThemeColorKey),
      customBgColorHex: _prefs.getString(_kCustomBgColorKey),
      customTextColorHex: _prefs.getString(_kCustomTextColorKey),
      customChordColorHex: _prefs.getString(_kCustomChordColorKey),
      customLyricColorHex: _prefs.getString(_kCustomLyricColorKey),
      fontFamily: _prefs.getString(_kFontFamilyKey),
    );
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(defaultFontSize: size);
    await _prefs.setDouble(_kFontSizeKey, size);
  }

  Future<void> setCustomThemeColorHex(String hex) async {
    state = state.copyWith(customThemeColorHex: hex);
    await _prefs.setString(_kCustomThemeColorKey, hex);
  }

  Future<void> setCustomBgColorHex(String hex) async {
    state = state.copyWith(customBgColorHex: hex);
    await _prefs.setString(_kCustomBgColorKey, hex);
  }

  Future<void> setCustomTextColorHex(String hex) async {
    state = state.copyWith(customTextColorHex: hex);
    await _prefs.setString(_kCustomTextColorKey, hex);
  }

  Future<void> setCustomChordColorHex(String hex) async {
    state = state.copyWith(customChordColorHex: hex);
    await _prefs.setString(_kCustomChordColorKey, hex);
  }

  Future<void> setCustomLyricColorHex(String hex) async {
    state = state.copyWith(customLyricColorHex: hex);
    await _prefs.setString(_kCustomLyricColorKey, hex);
  }

  Future<void> setFontFamily(String font) async {
    state = state.copyWith(fontFamily: font);
    await _prefs.setString(_kFontFamilyKey, font);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});
