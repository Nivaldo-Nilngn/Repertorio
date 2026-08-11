// ignore_for_file: avoid_print
import 'package:firebase_database/firebase_database.dart';
import 'prefs_sync_domain.dart';

/// I/O puro de Realtime Database para as preferências do usuário.
/// Espelha o estilo do MidiStorageService: dependências injetadas,
/// erros tratados com print e nunca lança para o chamador.
class UserSettingsSyncService {
  final DatabaseReference _prefsRef;
  final bool _isSignedIn; // false quando não logado

  UserSettingsSyncService(this._prefsRef, this._isSignedIn);

  bool get isSignedIn => _isSignedIn;

  /// Referência da chave legada (fora de /prefs) para migração.
  DatabaseReference get _legacyViewModeRef =>
      _prefsRef.parent!.child(kLegacyViewModeKey);

  /// Retorna o snapshot inteiro de settings/prefs como Map.
  /// Nunca lança: em erro retorna {}.
  Future<Map<String, dynamic>> loadPrefs() async {
    if (!_isSignedIn) return {};
    try {
      final snapshot = await _prefsRef.get();
      if (snapshot.exists && snapshot.value != null && snapshot.value is Map) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
    } catch (e) {
      print('Erro ao carregar prefs do Firebase: $e');
    }
    return {};
  }

  /// Grava apenas as chaves presentes no map (update, não set —
  /// protege activeMidiProfileId e outras chaves do nó settings).
  Future<void> writePrefs(Map<String, dynamic> values) async {
    if (!_isSignedIn || values.isEmpty) return;
    try {
      await _prefsRef.update(values);
    } catch (e) {
      print('Erro ao salvar preferências no Firebase: $e');
    }
  }

  /// Sobe todas as preferências locais de uma vez (1º login / seed)
  /// e remove a chave legada depois do sucesso.
  Future<void> seedPrefs(Map<String, dynamic> localValues) async {
    if (!_isSignedIn) return;
    try {
      await _prefsRef.update(localValues);
      // Migração: limpa settings/last_song_view_mode antigo (vai para /prefs)
      try {
        await _legacyViewModeRef.remove();
      } catch (e) {
        print('Erro ao remover last_song_view_mode legado: $e');
      }
    } catch (e) {
      print('Erro ao enviar prefs para o Firebase: $e');
    }
  }

  /// Lê o valor migrável de settings/last_song_view_mode (usuários antigos).
  Future<String?> readLegacyViewMode() async {
    if (!_isSignedIn) return null;
    try {
      final snapshot = await _legacyViewModeRef.get();
      if (snapshot.exists && snapshot.value != null) {
        return snapshot.value.toString();
      }
    } catch (e) {
      print('Erro ao ler last_song_view_mode legado: $e');
    }
    return null;
  }
}