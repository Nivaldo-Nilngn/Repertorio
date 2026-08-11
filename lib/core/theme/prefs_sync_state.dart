import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'prefs_sync_domain.dart';
import 'user_settings_sync_service.dart';

/// uid reativo do usuário logado (ou null quando deslogado).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

/// Instância do serviço de sincronização para o uid atual.
final userSettingsSyncServiceProvider = Provider<UserSettingsSyncService>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return UserSettingsSyncService(
    uid != null
        ? prefsRef(FirebaseDatabase.instance, uid)
        : FirebaseDatabase.instance.ref('users/none/settings/prefs'),
    uid != null,
  );
});

// ---- Flag anti-loop: durante o pull, os setters não reenviam à nuvem ----

class PrefsSyncActive {
  final String? uid; // uid que a rodada de pull aplicou
  final bool active; // true enquanto a sincronização está em curso

  const PrefsSyncActive({required this.uid, required this.active});

  bool shouldPush(String? currentUid) =>
      currentUid != null && (!active || currentUid != uid);
}

class PrefsSyncActiveNotifier extends Notifier<PrefsSyncActive> {
  @override
  PrefsSyncActive build() => const PrefsSyncActive(uid: null, active: false);

  void begin(String uid) {
    state = PrefsSyncActive(uid: uid, active: true);
  }

  void end() {
    state = const PrefsSyncActive(uid: null, active: false);
  }
}

final prefsSyncActiveProvider =
    NotifierProvider<PrefsSyncActiveNotifier, PrefsSyncActive>(() {
  return PrefsSyncActiveNotifier();
});