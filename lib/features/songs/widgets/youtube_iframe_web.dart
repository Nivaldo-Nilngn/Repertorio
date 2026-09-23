// ignore_for_file: avoid_web_libraries_in_flutter
// Web-only YouTube iframe helper for song_viewer_screen.dart.
// Only compiled when dart.library.html is available (web targets).

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final _registeredYoutubeIds = <String>{};
final _iframeElements = <String, html.IFrameElement>{};

void registerYoutubeIframe(String videoUrl, String videoId) {
  final viewId = 'youtube-iframe-$videoUrl';
  if (_registeredYoutubeIds.contains(viewId)) return;
  _registeredYoutubeIds.add(viewId);

  final iframe = html.IFrameElement()
    ..width = '100%'
    ..height = '100%'
    ..src = 'https://www.youtube.com/embed/$videoId?enablejsapi=1&autoplay=0'
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..allow =
        'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
    ..allowFullscreen = true;

  _iframeElements[viewId] = iframe;

  try {
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) => iframe);
  } catch (_) {
    // Already registered — safe to ignore
  }
}

Widget buildYoutubeView(String videoUrl) {
  final viewId = 'youtube-iframe-$videoUrl';
  return AspectRatio(
    aspectRatio: 16 / 9,
    child: HtmlElementView(viewType: viewId),
  );
}
