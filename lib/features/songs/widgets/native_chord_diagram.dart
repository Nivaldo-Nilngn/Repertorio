import 'package:flutter/material.dart';
import 'package:flutter_guitar_chord/flutter_guitar_chord.dart';
import 'package:guitar_chord_library/guitar_chord_library.dart';

class NativeChordDiagram extends StatelessWidget {
  final String chordName;
  final double width;
  final double height;
  final Color? stringColor;
  final Color? barColor;
  final Color? labelColor;
  final Color? tabBackgroundColor;
  final Color? tabForegroundColor;
  final Color? mutedColor;

  const NativeChordDiagram({
    super.key,
    required this.chordName,
    this.width = 120,
    this.height = 140,
    this.stringColor,
    this.barColor,
    this.labelColor,
    this.tabBackgroundColor,
    this.tabForegroundColor,
    this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final parsed = _parseChordName(chordName);
    final positions = GuitarChordLibrary.instrument().getChordPositions(
      parsed.key,
      parsed.suffix,
    );

    if (positions == null || positions.isEmpty) {
      return _buildFallback(context, chordName);
    }

    final pos = positions.first;
    final effectiveStringColor = stringColor ?? colors.onSurface;
    final effectiveBarColor = barColor ?? colors.onSurface;
    final effectiveLabelColor = labelColor ?? colors.onSurface;

    return SizedBox(
      width: width,
      height: height,
      child: FlutterGuitarChord(
        frets: pos.frets,
        fingers: pos.fingers,
        baseFret: pos.baseFret,
        chordName: chordName,
        showLabel: true,
        labelOpenStrings: true,
        stringColor: effectiveStringColor,
        barColor: effectiveBarColor,
        firstFrameColor: effectiveBarColor,
        labelColor: effectiveLabelColor,
        tabBackgroundColor: tabBackgroundColor ?? colors.surfaceContainerHighest,
        tabForegroundColor: tabForegroundColor ?? Colors.white,
        mutedColor: mutedColor ?? colors.error,
      ),
    );
  }

  Widget _buildFallback(BuildContext context, String name) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, color: colors.outline, size: 32),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ChordParts _parseChordName(String name) {
    String clean = name
        .replaceAll('7M', 'maj7')
        .replaceAll('maj7', 'maj7')
        .replaceAll('º', 'dim')
        .replaceAll('°', 'dim')
        .replaceAll('-', 'm')
        .replaceAll('+', 'aug')
        .replaceAll('5', '5')
        .replaceAll('sus2', 'sus2')
        .replaceAll('sus4', 'sus4')
        .replaceAll('add9', 'add9');

    String root = '';
    String suffix = '';

    if (clean.length >= 2 && (clean[1] == '#' || clean[1] == 'b')) {
      root = clean.substring(0, 2);
      suffix = clean.substring(2);
    } else {
      root = clean.substring(0, 1);
      suffix = clean.substring(1);
    }

    suffix = suffix
        .replaceAll('m', 'minor')
        .replaceAll('min', 'minor')
        .replaceAll('M', 'maj')
        .replaceAll('maj', 'maj')
        .replaceAll('dim', 'dim')
        .replaceAll('aug', 'aug')
        .replaceAll('sus2', 'sus2')
        .replaceAll('sus4', 'sus4')
        .replaceAll('add9', 'add9')
        .replaceAll('7', '7')
        .replaceAll('9', '9')
        .replaceAll('11', '11')
        .replaceAll('13', '13')
        .replaceAll('5', '5');

    if (suffix.isEmpty || suffix == 'major') {
      suffix = 'major';
    }

    if (suffix == 'min') suffix = 'minor';
    if (suffix == 'm') suffix = 'minor';

    return _ChordParts(key: root, suffix: suffix);
  }
}

class _ChordParts {
  final String key;
  final String suffix;
  _ChordParts({required this.key, required this.suffix});
}
