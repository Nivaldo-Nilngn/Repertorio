import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class ChordApiViewer extends StatefulWidget {
  final String chord;
  final String instrument; // 'guitar' or 'piano'

  const ChordApiViewer({Key? key, required this.chord, required this.instrument}) : super(key: key);

  @override
  State<ChordApiViewer> createState() => _ChordApiViewerState();
}

class _ChordApiViewerState extends State<ChordApiViewer> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'chord-api-${widget.chord}-${widget.instrument}-${DateTime.now().millisecondsSinceEpoch}';
    
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..width = '100%'
        ..height = '100%'
        ..style.border = 'none'
        ..style.setProperty('pointer-events', 'none')
        ..srcdoc = '''
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              html, body {
                margin: 0; padding: 0; height: 100%; width: 100%;
                display: flex; justify-content: center; align-items: center;
                background-color: transparent;
                overflow: hidden;
              }
              ins {
                width: 100%;
                height: 100%;
                display: flex !important;
                justify-content: center;
                align-items: center;
              }
              img {
                width: 100%;
                height: 100%;
              }
              /* Specific adjustments for Piano */
              .instrument-piano img {
                object-fit: cover;
                object-position: bottom center;
              }
              /* Specific adjustments for Guitar */
              .instrument-guitar img {
                object-fit: contain;
              }
            </style>
            <script async type="text/javascript" src="https://www.scales-chords.com/api/scales-chords-api.js"></script>
          </head>
          <body class="instrument-${widget.instrument}">
            <ins class="scales_chords_api" chord="${widget.chord}" instrument="${widget.instrument}"></ins>
          </body>
          </html>
        ''';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.instrument == 'guitar' ? 140 : 80,
      width: double.infinity,
      color: Colors.white,
      child: Stack(
        children: [
          HtmlElementView(viewType: _viewType),
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
