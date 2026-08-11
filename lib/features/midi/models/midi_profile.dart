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
  final Map<String, List<MidiCommand>> mappings;
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
    Map<String, List<MidiCommand>>? mappings,
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
      'mappings': mappings.map(
        (k, v) => MapEntry(k, v.map((cmd) => cmd.toJson()).toList()),
      ),
      'inputId': inputId,
      'outputId': outputId,
      'channel': channel,
    };
  }

  factory MidiProfile.fromJson(Map<String, dynamic> json) {
    // O RTDB devolve mapas com operadores Object? (não Map<String, dynamic>).
    // Normaliza todos os valores para strings preservando o conteúdo.
    final mapped = json.map((k, v) => MapEntry(k.toString(), v));
    Map<dynamic, dynamic>? rawMappings;
    final raw = mapped['mappings'];
    if (raw is Map) {
      rawMappings = raw.cast<dynamic, dynamic>();
    } else if (raw is List) {
      rawMappings = {};
      for (final item in raw) {
        if (item is Map) {
          final m = item.cast<dynamic, dynamic>();
          rawMappings[rawMappings.length.toString()] = m;
        }
      }
    }

    final mappings = <String, List<MidiCommand>>{};
    if (rawMappings != null) {
      rawMappings.forEach((k, v) {
        try {
          if (v is Map) {
            // Um EditorCommand por chave (objeto único)
            final entryMap = <String, dynamic>{};
            v.forEach((kk, vv) => entryMap[kk.toString()] = vv);
            final existing = mappings[k.toString()] ?? <MidiCommand>[];
            existing.add(MidiCommand.fromJson(entryMap));
            mappings[k.toString()] = existing;
          } else if (v is List) {
            // Lista de comandos para a mesma ação
            final existing = mappings[k.toString()] ?? <MidiCommand>[];
            for (final item in v) {
              if (item is Map) {
                final entryMap = <String, dynamic>{};
                item.forEach((kk, vv) => entryMap[kk.toString()] = vv);
                existing.add(MidiCommand.fromJson(entryMap));
              }
            }
            mappings[k.toString()] = existing;
          }
        } catch (_) {}
      });
    }
    
    return MidiProfile(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Perfil',
      mappings: mappings,
      inputId: json['inputId']?.toString(),
      outputId: json['outputId']?.toString(),
      channel: json['channel'] is int ? json['channel'] as int : (json['channel'] != null ? int.tryParse(json['channel'].toString()) ?? 0 : 0),
    );
  }
}
