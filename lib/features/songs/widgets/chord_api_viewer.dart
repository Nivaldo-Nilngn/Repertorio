// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Web-only imports guarded by conditional — only referenced inside kIsWeb blocks
// so they compile fine on mobile (tree-shaken away by the Dart compiler).
import 'chord_api_viewer_web.dart' if (dart.library.io) 'chord_api_viewer_stub.dart'
    as platform;

/// Shows a chord diagram fetched from scales-chords.com.
///
/// On web: renders via an iframe (scales-chords API).
/// On mobile: shows a text label with the chord name (NativeChordDiagram
/// handles the visual diagram rendering via flutter_guitar_chord).
class ChordApiViewer extends StatefulWidget {
  final String chord;
  final String instrument; // 'guitar' or 'piano'

  const ChordApiViewer(
      {Key? key, required this.chord, required this.instrument})
      : super(key: key);

  @override
  State<ChordApiViewer> createState() => _ChordApiViewerState();
}

class _ChordApiViewerState extends State<ChordApiViewer> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      platform.registerChordViewFactory(widget.chord, widget.instrument);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Mobile: just show the chord name — NativeChordDiagram handles visuals
      return Container(
        height: widget.instrument == 'guitar' ? 140 : 80,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.chord,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    return platform.buildChordView(context, widget.chord, widget.instrument);
  }
}
