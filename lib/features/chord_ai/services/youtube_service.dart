import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YouTubeVideoItem {
  final String id;
  final String title;
  final String author;
  final String duration;
  final String thumbnailUrl;

  YouTubeVideoItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
  });
}

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  static const List<YouTubeVideoItem> suggestions = [];

  static String get _baseUrl {
    const fromEnv = String.fromEnvironment('CHORD_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Busca músicas reais no YouTube através do backend com yt-dlp ou nativo
  Future<List<YouTubeVideoItem>> searchVideos(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Se for um link direto do YouTube ou um ID de 11 caracteres, extrai imediatamente
    final directId = YoutubePlayerController.convertUrlToId(cleanQuery);
    if (directId != null && directId.isNotEmpty) {
      return [
        YouTubeVideoItem(
          id: directId,
          title: 'Vídeo do YouTube ($directId)',
          author: 'YouTube',
          duration: '03:45',
          thumbnailUrl: 'https://img.youtube.com/vi/$directId/hqdefault.jpg',
        ),
      ];
    }

    // 2. Busca prioritária via backend local com yt-dlp (rápido, 100% real, sem bloqueios de CORS)
    try {
      final backendResults = await _searchBackend(cleanQuery);
      if (backendResults.isNotEmpty) {
        return backendResults;
      }
    } catch (e) {
      debugPrint('[YouTubeService] Erro na busca do backend: $e');
    }

    // 3. Fallback nativo usando YoutubeExplode (para plataformas não-web)
    if (!kIsWeb) {
      try {
        final nativeResults = await _searchNative(cleanQuery);
        if (nativeResults.isNotEmpty) {
          return nativeResults;
        }
      } catch (e) {
        debugPrint('[YouTubeService] Erro na busca nativa: $e');
      }
    }

    return [];
  }

  /// Busca real via endpoint do backend (/search?q=...) usando yt-dlp
  Future<List<YouTubeVideoItem>> _searchBackend(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('$_baseUrl/search?q=$encoded');

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode == 200) {
      final data = json.decode(utf8.decode(res.bodyBytes));
      if (data is List) {
        final List<YouTubeVideoItem> list = [];
        for (final item in data) {
          final id = item['id'] as String? ?? '';
          if (id.isNotEmpty && id.length == 11) {
            list.add(
              YouTubeVideoItem(
                id: id,
                title: item['title'] as String? ?? 'Sem título',
                author: item['author'] as String? ?? 'YouTube',
                duration: item['duration'] as String? ?? '00:00',
                thumbnailUrl: item['thumbnailUrl'] as String? ??
                    'https://img.youtube.com/vi/$id/hqdefault.jpg',
              ),
            );
          }
        }
        return list;
      }
    }
    return [];
  }

  /// Busca nativa (Linux / Android) usando YoutubeExplode
  Future<List<YouTubeVideoItem>> _searchNative(String query) async {
    final searchList = await _yt.search.search(query);
    final List<YouTubeVideoItem> results = [];

    for (final video in searchList.take(15)) {
      results.add(
        YouTubeVideoItem(
          id: video.id.value,
          title: video.title,
          author: video.author,
          duration: _formatDuration(video.duration ?? Duration.zero),
          thumbnailUrl:
              'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg',
        ),
      );
    }
    return results;
  }

  /// Extrai URL de áudio (para mobile/desktop nativo)
  Future<String?> getAudioStreamUrl(String videoId) async {
    if (!kIsWeb) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(videoId);
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isNotEmpty) {
          return audioStreams.withHighestBitrate().url.toString();
        }
      } catch (_) {}
    }
    return null;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void dispose() {
    _yt.close();
  }
}
