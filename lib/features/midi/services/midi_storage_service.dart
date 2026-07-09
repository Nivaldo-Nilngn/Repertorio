// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import '../models/midi_profile.dart';

class MidiStorageService {
  static const _storageKey = 'kordapp_midi_profiles';
  static const _activeProfileKey = 'kordapp_active_midi_profile_id';

  List<MidiProfile> loadProfiles() {
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
      print('Erro ao carregar perfis MIDI: $e');
      return [
        const MidiProfile(id: 'default', name: 'Perfil Padrão', mappings: {}),
      ];
    }
  }

  void saveProfiles(List<MidiProfile> profiles) {
    final encoded = jsonEncode(profiles.map((e) => e.toJson()).toList());
    html.window.localStorage[_storageKey] = encoded;
  }

  String? loadActiveProfileId() {
    return html.window.localStorage[_activeProfileKey];
  }

  void saveActiveProfileId(String id) {
    html.window.localStorage[_activeProfileKey] = id;
  }
}
