import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/manager_providers.dart';

class EditingChordProNotifier extends Notifier<String> {
  @override
  String build() => '''{title: Nova Música}
{artist: Artista}
{key: C}
{tempo: 70}

{c: Verse 1}
Coloque sua [C]letra aqui
E os acordes [G]entre colchetes
''';
}

final editingChordProProvider = NotifierProvider<EditingChordProNotifier, String>(() {
  return EditingChordProNotifier();
});
class IsEditorVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final isEditorVisibleProvider = NotifierProvider<IsEditorVisibleNotifier, bool>(() {
  return IsEditorVisibleNotifier();
});

class SelectedSongIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    state = id;
  }
}

final selectedSongIdProvider = NotifierProvider<SelectedSongIdNotifier, String?>(() {
  return SelectedSongIdNotifier();
});

// Tracks which tab was active when the editor was opened, so we can return to it on save/close.
class EditorOriginTabNotifier extends Notifier<SidebarTab?> {
  @override
  SidebarTab? build() => null;

  void setOrigin(SidebarTab tab) {
    state = tab;
  }

  void clear() {
    state = null;
  }
}

final editorOriginTabProvider = NotifierProvider<EditorOriginTabNotifier, SidebarTab?>(() {
  return EditorOriginTabNotifier();
});
