// ignore_for_file: avoid_web_libraries_in_flutter
// Web implementation of the chord diagram iframe helpers.

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final _registered = <String>{};

void registerChordViewFactory(String chord, String instrument) {
  final viewType =
      'chord-api-$chord-$instrument';
  if (_registered.contains(viewType)) return;
  _registered.add(viewType);

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
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
            img { width: 100%; height: 100%; }
            .instrument-piano img { object-fit: cover; object-position: bottom center; }
            .instrument-guitar img { object-fit: contain; }
          </style>
          <script async type="text/javascript"
            src="https://www.scales-chords.com/api/scales-chords-api.js"></script>
        </head>
        <body class="instrument-$instrument">
          <ins class="scales_chords_api" chord="$chord" instrument="$instrument"></ins>
        </body>
        </html>
      ''';
  });
}

Widget buildChordView(BuildContext context, String chord, String instrument) {
  final viewType = 'chord-api-$chord-$instrument';
  return Container(
    height: instrument == 'guitar' ? 140 : 80,
    width: double.infinity,
    color: Colors.white,
    child: Stack(
      children: [
        HtmlElementView(viewType: viewType),
        Positioned.fill(child: Container(color: Colors.transparent)),
      ],
    ),
  );
}
