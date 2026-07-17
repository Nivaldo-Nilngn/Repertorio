import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/midi_profile.dart';
import '../services/midi_service.dart';
import '../services/midi_storage_service.dart';
import '../services/midi_web_service.dart';

import 'package:firebase_database/firebase_database.dart';
import '../../auth/providers/auth_provider.dart';

final midiStorageServiceProvider = Provider<MidiStorageService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return MidiStorageService(
    database: FirebaseDatabase.instance,
    userId: auth.currentUser?.uid,
  );
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
  final List<MidiOutputDevice> outputs;
  final String? activeOutputId;
  final int activeChannel; // 0 = Omni, 1-16
  final bool isReceivingSignal;
  final List<MidiProfile> profiles;
  final String activeProfileId;
  final bool isLearning;
  final String? learningAction;

  final List<String> recentEvents;

  MidiState({
    this.isSupported = false,
    this.inputs = const [],
    this.activeInputId,
    this.outputs = const [],
    this.activeOutputId,
    this.activeChannel = 0,
    this.isReceivingSignal = false,
    this.profiles = const [],
    this.activeProfileId = 'default',
    this.isLearning = false,
    this.learningAction,
    this.recentEvents = const [],
  });

  MidiProfile get activeProfile =>
      profiles.firstWhere((p) => p.id == activeProfileId, orElse: () => profiles.first);

  MidiState copyWith({
    bool? isSupported,
    List<MidiInputDevice>? inputs,
    String? activeInputId,
    List<MidiOutputDevice>? outputs,
    String? activeOutputId,
    int? activeChannel,
    bool? isReceivingSignal,
    List<MidiProfile>? profiles,
    String? activeProfileId,
    bool? isLearning,
    String? learningAction,
    List<String>? recentEvents,
  }) {
    return MidiState(
      isSupported: isSupported ?? this.isSupported,
      inputs: inputs ?? this.inputs,
      activeInputId: activeInputId ?? this.activeInputId,
      outputs: outputs ?? this.outputs,
      activeOutputId: activeOutputId ?? this.activeOutputId,
      activeChannel: activeChannel ?? this.activeChannel,
      isReceivingSignal: isReceivingSignal ?? this.isReceivingSignal,
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      isLearning: isLearning ?? this.isLearning,
      learningAction: learningAction ?? this.learningAction,
      recentEvents: recentEvents ?? this.recentEvents,
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
    final profiles = await _storage.loadProfiles();
    final activeProfileId = await _storage.loadActiveProfileId() ?? profiles.first.id;

    final isSupported = await _midiService.initialize();
    
    if (isSupported) {
      _refreshInputs();
      _refreshOutputs();
      _stateChangeSub = _midiService.onStateChange.listen((_) {
        _refreshInputs();
        _refreshOutputs();
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

  void _refreshOutputs() {
    final outputs = _midiService.getOutputs();
    final activeId = outputs.isNotEmpty ? outputs.first.id : null;
    state = state.copyWith(outputs: outputs, activeOutputId: state.activeOutputId ?? activeId);
  }

  void setActiveInput(String inputId) {
    state = state.copyWith(activeInputId: inputId);
    _updateActiveProfile(inputId: inputId);
  }

  void setActiveOutput(String outputId) {
    state = state.copyWith(activeOutputId: outputId);
    _updateActiveProfile(outputId: outputId);
  }

  void setActiveChannel(int channel) {
    state = state.copyWith(activeChannel: channel);
    _updateActiveProfile(channel: channel);
  }

  void _updateActiveProfile({String? inputId, String? outputId, int? channel}) {
    final profile = state.activeProfile;
    final updatedProfile = profile.copyWith(
      inputId: inputId ?? profile.inputId,
      outputId: outputId ?? profile.outputId,
      channel: channel ?? profile.channel,
    );
    final updatedProfiles = state.profiles.map((p) => p.id == updatedProfile.id ? updatedProfile : p).toList();
    state = state.copyWith(profiles: updatedProfiles);
    _storage.saveProfiles(updatedProfiles);
  }

  void triggerPanic() {
    if (state.activeOutputId != null) {
      _midiService.sendPanic(state.activeOutputId!, channel: state.activeChannel);
    }
  }

  void setActiveProfile(String profileId) {
    final profile = state.profiles.firstWhere((p) => p.id == profileId, orElse: () => state.profiles.first);
    state = state.copyWith(
      activeProfileId: profileId,
      activeInputId: profile.inputId,
      activeOutputId: profile.outputId,
      activeChannel: profile.channel,
    );
    _storage.saveActiveProfileId(profileId);
  }

  void addProfile(String name) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newProfile = MidiProfile(
      id: id, 
      name: name,
      inputId: state.activeInputId,
      outputId: state.activeOutputId,
      channel: state.activeChannel,
    );
    final updated = [...state.profiles, newProfile];
    state = state.copyWith(profiles: updated, activeProfileId: id);
    _storage.saveProfiles(updated);
    _storage.saveActiveProfileId(id);
  }

  void deleteProfile(String profileId) {
    if (state.profiles.length <= 1) return; // Cannot delete the last profile
    
    final updated = state.profiles.where((p) => p.id != profileId).toList();
    state = state.copyWith(profiles: updated);
    _storage.saveProfiles(updated);

    if (state.activeProfileId == profileId) {
      setActiveProfile(updated.first.id);
    }
  }

  void startLearning(String action) {
    state = state.copyWith(isLearning: true, learningAction: action);
  }

  void cancelLearning() {
    state = state.copyWith(isLearning: false, learningAction: null);
  }

  void removeMapping(String actionKey) {
    final profile = state.activeProfile;
    final updatedMappings = Map<String, MidiCommand>.from(profile.mappings);
    updatedMappings.remove(actionKey);
    
    final updatedProfile = profile.copyWith(mappings: updatedMappings);
    final updatedProfiles = state.profiles.map((p) => p.id == updatedProfile.id ? updatedProfile : p).toList();
    
    state = state.copyWith(profiles: updatedProfiles);
    _storage.saveProfiles(updatedProfiles);
  }

  void clearAllMappings() {
    final profile = state.activeProfile;
    final updatedProfile = profile.copyWith(mappings: const {});
    final updatedProfiles = state.profiles.map((p) => p.id == updatedProfile.id ? updatedProfile : p).toList();
    
    state = state.copyWith(profiles: updatedProfiles);
    _storage.saveProfiles(updatedProfiles);
  }

  void _onMidiMessage(MidiMessageEvent event) {
    // Only process from active input device if one is selected
    if (state.activeInputId != null && event.portId != state.activeInputId) {
      return;
    }

    final cmd = MidiCommand(command: event.command, noteOrCc: event.note);

    // Add to recent events log
    final nowTime = DateTime.now();
    final timeStr = "${nowTime.hour.toString().padLeft(2, '0')}:${nowTime.minute.toString().padLeft(2, '0')}:${nowTime.second.toString().padLeft(2, '0')}";
    final eventStr = "[$timeStr] Sinal ${cmd.command} (N/CC: ${cmd.noteOrCc})";
    
    final newEvents = [eventStr, ...state.recentEvents];
    if (newEvents.length > 5) newEvents.removeLast();

    // Flash the LED and update log
    if (!state.isReceivingSignal) {
      state = state.copyWith(isReceivingSignal: true, recentEvents: newEvents);
      Future.delayed(const Duration(milliseconds: 150), () {
        try {
          state = state.copyWith(isReceivingSignal: false);
        } catch (_) {}
      });
    } else {
      state = state.copyWith(recentEvents: newEvents);
    }

    // Ignore Note Off for mapping and execution
    if (event.isNoteOff) return;

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
