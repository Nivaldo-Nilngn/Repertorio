import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/midi_profile.dart';
import '../services/midi_service.dart';
import '../services/midi_storage_service.dart';
import '../services/midi_web_service.dart';

final midiStorageServiceProvider = Provider<MidiStorageService>((ref) {
  return MidiStorageService();
});

final midiServiceProvider = Provider<MidiService>((ref) {
  final service = MidiService();
  ref.onDispose(() => service.dispose());
  return service;
});

class MidiState {
  final bool isSupported;
  final List<MidiInputDevice> inputs;
  final String? activeInputId;
  final List<MidiProfile> profiles;
  final String activeProfileId;
  final bool isLearning;
  final String? learningAction;

  MidiState({
    this.isSupported = false,
    this.inputs = const [],
    this.activeInputId,
    this.profiles = const [],
    this.activeProfileId = 'default',
    this.isLearning = false,
    this.learningAction,
  });

  MidiProfile get activeProfile =>
      profiles.firstWhere((p) => p.id == activeProfileId, orElse: () => profiles.first);

  MidiState copyWith({
    bool? isSupported,
    List<MidiInputDevice>? inputs,
    String? activeInputId,
    List<MidiProfile>? profiles,
    String? activeProfileId,
    bool? isLearning,
    String? learningAction,
  }) {
    return MidiState(
      isSupported: isSupported ?? this.isSupported,
      inputs: inputs ?? this.inputs,
      activeInputId: activeInputId ?? this.activeInputId,
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      isLearning: isLearning ?? this.isLearning,
      learningAction: learningAction ?? this.learningAction,
    );
  }
}

class MidiNotifier extends Notifier<MidiState> {
  late final MidiService _midiService;
  late final MidiStorageService _storage;
  StreamSubscription? _midiSub;
  StreamSubscription? _stateChangeSub;

  // Track last command for debounce
  MidiCommand? _lastCommand;
  DateTime? _lastCommandTime;

  @override
  MidiState build() {
    _midiService = ref.read(midiServiceProvider);
    _storage = ref.read(midiStorageServiceProvider);
    
    ref.onDispose(() {
      _midiSub?.cancel();
      _stateChangeSub?.cancel();
    });

    Future.microtask(() => _init());
    return MidiState();
  }

  Future<void> _init() async {
    final profiles = _storage.loadProfiles();
    final activeProfileId = _storage.loadActiveProfileId() ?? profiles.first.id;

    final isSupported = await _midiService.initialize();
    
    if (isSupported) {
      _refreshInputs();
      _stateChangeSub = _midiService.onStateChange.listen((_) {
        _refreshInputs();
      });
      _midiSub = _midiService.onMessage.listen(_onMidiMessage);
    }

    state = state.copyWith(
      isSupported: isSupported,
      profiles: profiles,
      activeProfileId: activeProfileId,
    );
  }

  void _refreshInputs() {
    final inputs = _midiService.getInputs();
    final activeId = inputs.isNotEmpty ? inputs.first.id : null;
    state = state.copyWith(inputs: inputs, activeInputId: state.activeInputId ?? activeId);
  }

  void setActiveInput(String inputId) {
    state = state.copyWith(activeInputId: inputId);
  }

  void setActiveProfile(String profileId) {
    state = state.copyWith(activeProfileId: profileId);
    _storage.saveActiveProfileId(profileId);
  }

  void addProfile(String name) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newProfile = MidiProfile(id: id, name: name);
    final updated = [...state.profiles, newProfile];
    state = state.copyWith(profiles: updated, activeProfileId: id);
    _storage.saveProfiles(updated);
    _storage.saveActiveProfileId(id);
  }

  void startLearning(String action) {
    state = state.copyWith(isLearning: true, learningAction: action);
  }

  void cancelLearning() {
    state = state.copyWith(isLearning: false, learningAction: null);
  }

  void _onMidiMessage(MidiMessageEvent event) {
    // Only process from active input device if one is selected
    if (state.activeInputId != null && event.portId != state.activeInputId) {
      return;
    }

    // Ignore Note Off
    if (event.isNoteOff) return;

    final cmd = MidiCommand(command: event.command, noteOrCc: event.note);

    if (state.isLearning && state.learningAction != null) {
      // Check for conflicts
      final profile = state.activeProfile;
      String? conflictingAction;
      profile.mappings.forEach((action, mapping) {
        if (mapping == cmd) conflictingAction = action;
      });

      if (conflictingAction != null && conflictingAction != state.learningAction) {
        // We could emit a conflict warning, but for now we just overwrite
      }

      final updatedMappings = Map<String, MidiCommand>.from(profile.mappings);
      updatedMappings[state.learningAction!] = cmd;
      
      final updatedProfile = profile.copyWith(mappings: updatedMappings);
      final updatedProfiles = state.profiles.map((p) => p.id == updatedProfile.id ? updatedProfile : p).toList();
      
      state = state.copyWith(
        profiles: updatedProfiles,
        isLearning: false,
        learningAction: null,
      );
      _storage.saveProfiles(updatedProfiles);
    } else {
      // Execution mode
      final now = DateTime.now();
      if (_lastCommand == cmd && _lastCommandTime != null) {
        final diff = now.difference(_lastCommandTime!);
        if (diff.inMilliseconds < 200) {
          // Debounce
          return;
        }
      }

      _lastCommand = cmd;
      _lastCommandTime = now;

      // Find matching action
      final profile = state.activeProfile;
      String? matchedAction;
      profile.mappings.forEach((action, mapping) {
        if (mapping == cmd) matchedAction = action;
      });

      if (matchedAction != null) {
        ref.read(midiActionStreamProvider.notifier).dispatch(matchedAction!);
      }
    }
  }
}

final midiProvider = NotifierProvider<MidiNotifier, MidiState>(() {
  return MidiNotifier();
});

// A simple stream provider to broadcast the mapped actions (e.g. 'next_song')
class MidiActionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void dispatch(String action) {
    state = action;
    // Reset so the same action can be dispatched again
    Future.microtask(() => state = null);
  }
}

final midiActionStreamProvider = NotifierProvider<MidiActionNotifier, String?>(() {
  return MidiActionNotifier();
});
