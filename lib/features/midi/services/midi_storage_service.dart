// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'package:firebase_database/firebase_database.dart';
import '../models/midi_profile.dart';

class MidiStorageService {
  final FirebaseDatabase database;
  final String? userId;

  MidiStorageService({required this.database, this.userId});

  bool get isSignedIn => userId != null;

  static const _storageKey = 'kordapp_midi_profiles';
  static const _activeProfileKey = 'kordapp_active_midi_profile_id';

  // Evita re-seed indevido: só tenta subir os perfis locais se a nuvem
  // realmente não existir e ainda não tivermos tentado nesta sessão.
  bool _seeded = false;

  // Diagnóstico: quantos perfis vieram do snapshot da nuvem.
  int _cloudParsed = 0;

  DatabaseReference? get _profilesRef => userId != null ? database.ref('users/$userId/midiProfiles') : null;
  DatabaseReference? get _settingsRef => userId != null ? database.ref('users/$userId/settings') : null;

  Future<List<MidiProfile>> loadProfiles() async {
    if (_profilesRef != null) {
      try {
        final snapshot = await _profilesRef!.get();
        print('[MIDI] loadProfiles firebase snapshot.exists=${snapshot.exists}, value=${snapshot.value}');
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value;
          if (data is Map) {
            final map = Map<String, dynamic>.from(data);
            final List<MidiProfile> parsedProfiles = [];
            for (final entry in map.values) {
              try {
                if (entry is Map) {
                  parsedProfiles.add(MidiProfile.fromJson(Map<String, dynamic>.from(entry)));
                }
              } catch (e) {
                print('Erro ao parsear perfil MIDI: $e');
              }
            }
            if (parsedProfiles.isNotEmpty) {
              _seeded = true;
              _cloudParsed = parsedProfiles.length;
              html.window.localStorage[_storageKey] = jsonEncode(parsedProfiles.map((e) => e.toJson()).toList());
              print('[MIDI] loadProfiles cloud -> ${parsedProfiles.map((p) => p.name).toList()}');
              return parsedProfiles;
            }
            // Nuvem existia mas vazia/ilegível: considera "já iniciada"
            _seeded = true;
          } else if (data is List) {
            final list = List<dynamic>.from(data);
            final parsedProfiles = <MidiProfile>[];
            for (final e in list) {
              try {
                if (e != null && e is Map) {
                  parsedProfiles.add(MidiProfile.fromJson(Map<String, dynamic>.from(e)));
                }
              } catch (e2) {
                print('Erro ao parsear perfil MIDI (lista): $e2');
              }
            }
            if (parsedProfiles.isNotEmpty) {
              _seeded = true;
              _cloudParsed = parsedProfiles.length;
              html.window.localStorage[_storageKey] = jsonEncode(parsedProfiles.map((e) => e.toJson()).toList());
              print('[MIDI] loadProfiles list-cloud -> ${parsedProfiles.map((p) => p.name).toList()}');
              return parsedProfiles;
            }
            _seeded = true;
          }
        } else {
          // Snapshot sem dados: ainda não marcamos como vazio definitivo.
          // O seed só roda se realmente não houver nada na nuvem.
        }
      } catch (e) {
        print('Erro ao carregar perfis MIDI do Firebase: $e');
      }
    }

    // Fallback para o local storage — sem re-seed nesta sessão
    final localProfiles = _loadFromLocalStorage();

    print('[MIDI] loadProfiles -> userId=$userId, cloudProfiles=$_cloudParsed, localProfiles=${localProfiles.map((p) => p.name).toList()}');

    // Sobe os locais pra nuvem apenas na primeira vez (nuvem de fato vazia)
    if (_profilesRef != null && !_seeded) {
      final isModified = localProfiles.length > 1 || (localProfiles.isNotEmpty && localProfiles.first.mappings.isNotEmpty);
      if (isModified) {
        print('[MIDI] Seed: subindo ${localProfiles.length} perfis locais pra nuvem (userId=$userId)');
        _seeded = true;
        saveProfiles(localProfiles);
      } else {
        print('[MIDI] Sem seed: nuvem vazia e local sem perfis modificados.');
      }
    }

    return localProfiles;
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
