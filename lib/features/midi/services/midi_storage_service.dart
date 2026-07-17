// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'package:firebase_database/firebase_database.dart';
import '../models/midi_profile.dart';

class MidiStorageService {
  final FirebaseDatabase database;
  final String? userId;

  MidiStorageService({required this.database, this.userId});

  static const _storageKey = 'kordapp_midi_profiles';
  static const _activeProfileKey = 'kordapp_active_midi_profile_id';

  DatabaseReference? get _profilesRef => userId != null ? database.ref('users/$userId/midiProfiles') : null;
  DatabaseReference? get _settingsRef => userId != null ? database.ref('users/$userId/settings') : null;

  Future<List<MidiProfile>> loadProfiles() async {
    if (_profilesRef != null) {
      try {
        final snapshot = await _profilesRef!.get();
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value;
          if (data is Map) {
            final map = Map<String, dynamic>.from(data);
            final List<MidiProfile> parsedProfiles = [];
            for (final entry in map.values) {
              if (entry is Map) {
                parsedProfiles.add(MidiProfile.fromJson(Map<String, dynamic>.from(entry)));
              }
            }
            if (parsedProfiles.isNotEmpty) return parsedProfiles;
          } else if (data is List) {
            final list = List<dynamic>.from(data);
            final parsedProfiles = list.where((e) => e != null).map((e) {
              return MidiProfile.fromJson(Map<String, dynamic>.from(e as Map));
            }).toList();
            if (parsedProfiles.isNotEmpty) return parsedProfiles;
          }
        }
      } catch (e) {
        print('Erro ao carregar perfis MIDI do Firebase: $e');
      }
    }

    // Fallback to local storage
    return _loadFromLocalStorage();
  }

  List<MidiProfile> _loadFromLocalStorage() {
    final data = html.window.localStorage[_storageKey];
    if (data == null || data.isEmpty) {
      return [
        const MidiProfile(id: 'default', name: 'Perfil Padrão', mappings: {}),
      ];
    }

    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => MidiProfile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Erro ao carregar perfis MIDI locais: $e');
      return [
        const MidiProfile(id: 'default', name: 'Perfil Padrão', mappings: {}),
      ];
    }
  }

  Future<void> saveProfiles(List<MidiProfile> profiles) async {
    // Save to local storage as backup/offline
    final encoded = jsonEncode(profiles.map((e) => e.toJson()).toList());
    html.window.localStorage[_storageKey] = encoded;

    // Save to Firebase
    if (_profilesRef != null) {
      try {
        final map = <String, dynamic>{};
        for (final profile in profiles) {
          map[profile.id] = profile.toJson();
        }
        await _profilesRef!.set(map);
      } catch (e) {
        print('Erro ao salvar perfis MIDI no Firebase: $e');
      }
    }
  }

  Future<String?> loadActiveProfileId() async {
    if (_settingsRef != null) {
      try {
        final snapshot = await _settingsRef!.child('activeMidiProfileId').get();
        if (snapshot.exists && snapshot.value != null) {
          return snapshot.value.toString();
        }
      } catch (e) {
        print('Erro ao carregar perfil ativo do Firebase: $e');
      }
    }
    return html.window.localStorage[_activeProfileKey];
  }

  Future<void> saveActiveProfileId(String id) async {
    html.window.localStorage[_activeProfileKey] = id;
    if (_settingsRef != null) {
      try {
        await _settingsRef!.update({'activeMidiProfileId': id});
      } catch (e) {
        print('Erro ao salvar perfil ativo no Firebase: $e');
      }
    }
  }
}
