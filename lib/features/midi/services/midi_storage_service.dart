import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/midi_profile.dart';

/// Cross-platform MIDI storage service.
///
/// Uses [SharedPreferences] as the primary offline cache (works on web,
/// Android, and iOS — on web, SharedPreferences internally uses localStorage).
/// Firebase Realtime Database is used for cloud sync with a 3-second timeout
/// so the service never hangs when the device is on an offline Wi-Fi network
/// (e.g. the church mixer's local IP).
class MidiStorageService {
  final FirebaseDatabase database;
  final String? userId;
  final SharedPreferences? prefs;

  MidiStorageService({
    required this.database,
    this.userId,
    this.prefs,
  });

  bool get isSignedIn => userId != null;

  static const _baseProfilesKey = 'kordapp_midi_profiles';
  static const _baseActiveKey = 'kordapp_active_midi_profile_id';

  String get _userProfilesKey =>
      userId != null ? '${_baseProfilesKey}_$userId' : _baseProfilesKey;
  String get _userActiveKey =>
      userId != null ? '${_baseActiveKey}_$userId' : _baseActiveKey;

  DatabaseReference? get _profilesRef =>
      userId != null ? database.ref('users/$userId/midiProfiles') : null;
  DatabaseReference? get _settingsRef =>
      userId != null ? database.ref('users/$userId/settings') : null;

  // ─── Cache local (0ms, offline-first) ──────────────────────────────────────

  List<MidiProfile> loadProfilesFromCache() {
    // User-scoped key first, then base key as fallback for legacy data
    String? data = prefs?.getString(_userProfilesKey);
    data ??= prefs?.getString(_baseProfilesKey);

    if (data != null && data.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        final list = decoded
            .map((e) => MidiProfile.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          print('[MIDI] loadProfilesFromCache -> ${list.length} perfis');
          return list;
        }
      } catch (e) {
        print('[MIDI] Erro ao decodificar perfis locais: $e');
      }
    }

    return const [
      MidiProfile(id: 'default', name: 'Perfil Padrão', mappings: {}),
    ];
  }

  String loadActiveProfileIdFromCache(List<MidiProfile> availableProfiles) {
    String? id = prefs?.getString(_userActiveKey);
    id ??= prefs?.getString(_baseActiveKey);

    if (id != null && availableProfiles.any((p) => p.id == id)) {
      return id;
    }
    return availableProfiles.isNotEmpty ? availableProfiles.first.id : 'default';
  }

  // ─── Salvamento local imediato + sync em background ────────────────────────

  void saveProfiles(List<MidiProfile> profiles) {
    final encoded = jsonEncode(profiles.map((e) => e.toJson()).toList());

    // Write to both keys so old and new code can read it
    prefs?.setString(_userProfilesKey, encoded);
    prefs?.setString(_baseProfilesKey, encoded);

    // Background cloud sync with timeout — safe when offline
    if (_profilesRef != null) {
      final map = <String, dynamic>{};
      for (final profile in profiles) {
        map[profile.id] = profile.toJson();
      }
      _profilesRef!.set(map).timeout(const Duration(seconds: 4)).catchError(
        (e) => print('[MIDI] saveProfiles cloud timeout/offline: $e'),
      );
    }
  }

  void saveActiveProfileId(String id) {
    prefs?.setString(_userActiveKey, id);
    prefs?.setString(_baseActiveKey, id);

    if (_settingsRef != null) {
      _settingsRef!
          .update({'activeMidiProfileId': id})
          .timeout(const Duration(seconds: 4))
          .catchError(
            (e) =>
                print('[MIDI] saveActiveProfileId cloud timeout/offline: $e'),
          );
    }
  }

  // ─── Cloud sync (with 3s timeout — safe on mesa de som Wi-Fi) ─────────────

  Future<List<MidiProfile>?> fetchProfilesFromCloud() async {
    if (_profilesRef == null) return null;

    try {
      final snapshot =
          await _profilesRef!.get().timeout(const Duration(seconds: 3));
      if (!snapshot.exists || snapshot.value == null) return null;

      final data = snapshot.value;
      final List<MidiProfile> parsed = [];

      if (data is Map) {
        for (final entry in Map<String, dynamic>.from(data).values) {
          try {
            if (entry is Map) {
              parsed.add(
                  MidiProfile.fromJson(Map<String, dynamic>.from(entry)));
            }
          } catch (e) {
            print('[MIDI] Erro parsear perfil cloud: $e');
          }
        }
      } else if (data is List) {
        for (final entry in data) {
          try {
            if (entry is Map) {
              parsed.add(
                  MidiProfile.fromJson(Map<String, dynamic>.from(entry)));
            }
          } catch (e) {
            print('[MIDI] Erro parsear perfil cloud lista: $e');
          }
        }
      }

      if (parsed.isNotEmpty) {
        print('[MIDI] fetchProfilesFromCloud -> ${parsed.length} perfis da nuvem');
        final encoded = jsonEncode(parsed.map((e) => e.toJson()).toList());
        prefs?.setString(_userProfilesKey, encoded);
        prefs?.setString(_baseProfilesKey, encoded);
        return parsed;
      }
    } catch (e) {
      print('[MIDI] fetchProfilesFromCloud timeout/offline (mesa de som): $e');
    }
    return null;
  }

  Future<String?> fetchActiveProfileIdFromCloud() async {
    if (_settingsRef == null) return null;

    try {
      final snapshot = await _settingsRef!
          .child('activeMidiProfileId')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snapshot.exists && snapshot.value != null) {
        final id = snapshot.value.toString();
        prefs?.setString(_userActiveKey, id);
        prefs?.setString(_baseActiveKey, id);
        return id;
      }
    } catch (e) {
      print('[MIDI] fetchActiveProfileIdFromCloud timeout/offline: $e');
    }
    return null;
  }

  // ─── Legacy helpers (backward compat) ─────────────────────────────────────

  Future<List<MidiProfile>> loadProfiles() async {
    final cached = loadProfilesFromCache();
    final cloud = await fetchProfilesFromCloud();
    return cloud ?? cached;
  }

  Future<String?> loadActiveProfileId() async {
    final cached = loadActiveProfileIdFromCache(loadProfilesFromCache());
    final cloud = await fetchActiveProfileIdFromCloud();
    return cloud ?? cached;
  }
}
