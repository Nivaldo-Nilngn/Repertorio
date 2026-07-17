import 'package:flutter/foundation.dart';

class MidiCommand {
  final int command;
  final int noteOrCc;

  const MidiCommand({
    required this.command,
    required this.noteOrCc,
  });

  Map<String, dynamic> toJson() {
    return {
      'command': command,
      'noteOrCc': noteOrCc,
    };
  }

  factory MidiCommand.fromJson(Map<String, dynamic> json) {
    return MidiCommand(
      command: json['command'] as int,
      noteOrCc: json['noteOrCc'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MidiCommand && runtimeType == other.runtimeType && command == other.command && noteOrCc == other.noteOrCc;

  @override
  int get hashCode => command.hashCode ^ noteOrCc.hashCode;
}

class MidiProfile {
  final String id;
  final String name;
  final Map<String, MidiCommand> mappings;
  final String? inputId;
  final String? outputId;
  final int channel;

  const MidiProfile({
    required this.id,
    required this.name,
    this.mappings = const {},
    this.inputId,
    this.outputId,
    this.channel = 0,
  });

  MidiProfile copyWith({
    String? id,
    String? name,
    Map<String, MidiCommand>? mappings,
    String? inputId,
    String? outputId,
    int? channel,
  }) {
    return MidiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      mappings: mappings ?? this.mappings,
      inputId: inputId ?? this.inputId,
      outputId: outputId ?? this.outputId,
      channel: channel ?? this.channel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mappings': mappings.map((k, v) => MapEntry(k, v.toJson())),
      'inputId': inputId,
      'outputId': outputId,
      'channel': channel,
    };
  }

  factory MidiProfile.fromJson(Map<String, dynamic> json) {
    final mappingsJson = json['mappings'] as Map<String, dynamic>? ?? {};
    final mappings = mappingsJson.map(
      (k, v) => MapEntry(k, MidiCommand.fromJson(Map<String, dynamic>.from(v as Map))),
    );
    return MidiProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      mappings: mappings,
      inputId: json['inputId']?.toString(),
      outputId: json['outputId']?.toString(),
      channel: json['channel'] != null ? int.tryParse(json['channel'].toString()) ?? 0 : 0,
    );
  }
}
