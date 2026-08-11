import 'package:firebase_database/firebase_database.dart';

// Chaves de sincronização — espelham as chaves do SharedPreferences.
// Centraliza nomes e o caminho RTDB para não repetir literais nos providers.
class PrefsSyncKeys {
  static const themeType = 'theme_type';
  static const fontSize = 'default_font_size';
  static const customThemeColor = 'custom_theme_color';
  static const customBgColor = 'custom_bg_color';
  static const customTextColor = 'custom_text_color';
  static const customChordColor = 'custom_chord_color';
  static const customLyricColor = 'custom_lyric_color';
  static const fontFamily = 'font_family';
  static const lastSongViewMode = 'last_song_view_mode';
  static const isTopMenu = 'isTopMenu';
  static const pinnedArtists = 'pinned_artists';

  static const all = <String>{
    themeType,
    fontSize,
    customThemeColor,
    customBgColor,
    customTextColor,
    customChordColor,
    customLyricColor,
    fontFamily,
    lastSongViewMode,
    isTopMenu,
    pinnedArtists,
  };
}

// Chave legada: last_song_view_mode costumava ser gravado direto em
// users/<uid>/settings (fora de /prefs). Migramos para /prefs no seed.
const kLegacyViewModeKey = 'last_song_view_mode';

/// Caminho RTDB onde as preferências sincronizadas vivem.
DatabaseReference prefsRef(FirebaseDatabase database, String uid) =>
    database.ref('users/$uid/settings/prefs');
