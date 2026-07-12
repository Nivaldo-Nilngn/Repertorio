import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'settings_provider.dart';

class AppThemeNotifier extends Notifier<AppThemeType> {
  late SharedPreferences _prefs;

  @override
  AppThemeType build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    final themeString = _prefs.getString('theme_type');
    
    if (themeString != null) {
      return AppThemeType.values.firstWhere(
        (e) => e.name == themeString,
        orElse: () => AppThemeType.managerDark,
      );
    }
    return AppThemeType.managerDark;
  }

  void setTheme(AppThemeType type) {
    state = type;
    _prefs.setString('theme_type', type.name);
  }
}

final appThemeProvider = NotifierProvider<AppThemeNotifier, AppThemeType>(() {
  return AppThemeNotifier();
});