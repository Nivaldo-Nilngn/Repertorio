import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:musicifras/features/songs/utils/chord_transposer.dart';
import 'package:musicifras/features/songs/services/banana_cifras_parser.dart';

class CifraClubParser {
  // Troque pela URL do seu worker após o deploy (ex: https://cifra-proxy.SEU_SUBDOMINIO.workers.dev)
  static const String _proxyBaseUrl = 'https://cifra-proxy.nivaldo-nilngn.workers.dev';

  static Future<String> fetchAndParse(String url) async {
    if (!url.toLowerCase().contains('cifraclub') && !url.toLowerCase().contains('bananacifras')) {
      throw Exception('A URL informada não é suportada. Por favor, cole um link válido do Cifra Club ou Banana Cifras.');
    }

    int? targetKeyIndex;
    final uri = Uri.parse(url);
    if (uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      if (fragmentParams.containsKey('key')) {
        targetKeyIndex = int.tryParse(fragmentParams['key']!);
      }
    }

    final proxyUrl = '$_proxyBaseUrl?url=${Uri.encodeComponent(url)}';
    try {
      final response = await http.get(Uri.parse(proxyUrl));
      if (response.statusCode == 200) {
        final htmlContent = response.body;
        if (url.toLowerCase().contains('bananacifras')) {
          return await BananaCifrasParser.parseHtmlToChordPro(htmlContent, targetKeyIndex: targetKeyIndex);
        }
        return parseHtmlToChordPro(htmlContent, targetKeyIndex: targetKeyIndex);
      }
      throw Exception('Failed to fetch page (status ${response.statusCode})');
    } catch (e) {
      throw Exception('Error parsing URL: $e');
    }
  }

  /// Extracts title, artist and key from the new Cifra Club HTML structure.
  /// Tries multiple selectors for forward-compatibility.
  static ({String title, String artist, String key}) _extractMetadata(dom.Document document) {
    // --- TITLE ---
    // New structure: <h1 class="_5QAC sKA9"> or from <title> tag
    String title = 'Unknown Title';
    // Try h1 (new layout) – the text content may contain extra spans
    final h1 = document.querySelector('h1');
    if (h1 != null) {
      title = h1.text.trim();
    }
    // Fallback: old layout (.t1)
    if (title == 'Unknown Title' || title.isEmpty) {
      title = document.querySelector('.t1')?.text.trim() ?? 'Unknown Title';
    }
    // Fallback: <title> tag  e.g. "Atos 2 - Gabriela Rocha - Cifra Club"
    if (title == 'Unknown Title' || title.isEmpty) {
      final pageTitle = document.querySelector('title')?.text ?? '';
      if (pageTitle.contains(' - ')) {
        title = pageTitle.split(' - ').first.trim();
      }
    }
    // Fallback: JSON-LD MusicComposition name
    if (title == 'Unknown Title' || title.isEmpty) {
      title = _extractJsonLdField(document, 'MusicComposition', 'name') ?? 'Unknown Title';
    }

    // --- ARTIST ---
    // New structure: 2nd <h2> visible element, or <h2 class="...avtl1...">
    String artist = 'Unknown Artist';
    // Try the artist h2 (new layout)
    final h2Elements = document.querySelectorAll('h2');
    for (final h2 in h2Elements) {
      final cls = h2.attributes['class'] ?? '';
      // The artist h2 contains 'avtl1' in its class on the current layout
      if (cls.contains('avtl1') || cls.contains('zljom')) {
        artist = h2.text.trim();
        break;
      }
    }
    // Fallback: old layout (.t3)
    if (artist == 'Unknown Artist' || artist.isEmpty) {
      artist = document.querySelector('.t3')?.text.trim() ?? 'Unknown Artist';
    }
    // Fallback: JSON-LD byArtist name
    if (artist == 'Unknown Artist' || artist.isEmpty) {
      artist = _extractJsonLdArtist(document) ?? 'Unknown Artist';
    }
    // Fallback: parse from <title>
    if (artist == 'Unknown Artist' || artist.isEmpty) {
      final pageTitle = document.querySelector('title')?.text ?? '';
      final parts = pageTitle.split(' - ');
      if (parts.length >= 2) {
        artist = parts[1].trim();
      }
    }

    // --- KEY / TOM ---
    // New structure: <button data-anchor="--chord-tone">Em</button>
    String key = 'C';
    // Try new layout first: button with data-anchor="--chord-tone"
    final chordToneButton = document.querySelector('[data-anchor="--chord-tone"]');
    if (chordToneButton != null) {
      final btnText = chordToneButton.text.trim();
      if (btnText.isNotEmpty) {
        key = btnText;
      }
    }
    // Fallback: old layout (#cifra_tom a)
    if (key == 'C') {
      final oldKeyEl = document.querySelector('#cifra_tom a');
      if (oldKeyEl != null) {
        key = oldKeyEl.text.trim();
      } else {
        final tomContent = document.querySelector('#cifra_tom')?.text ?? '';
        final formaMatch = RegExp(r'forma dos acordes no tom de ([CDEFGAB][#b]?m?)', caseSensitive: false).firstMatch(tomContent);
        if (formaMatch != null) {
          key = formaMatch.group(1)!;
        }
      }
    }

    return (title: title, artist: artist, key: key);
  }

  /// Tries to extract a specific field from a JSON-LD script of a given @type.
  static String? _extractJsonLdField(dom.Document document, String type, String field) {
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      try {
        final data = json.decode(script.text) as Map<String, dynamic>;
        final dtype = data['@type'];
        final types = dtype is List ? dtype.cast<String>() : [dtype?.toString() ?? ''];
        if (types.contains(type)) {
          return data[field]?.toString();
        }
      } catch (_) {}
    }
    return null;
  }

  static String? _extractJsonLdArtist(dom.Document document) {
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      try {
        final data = json.decode(script.text) as Map<String, dynamic>;
        final byArtist = data['byArtist'];
        if (byArtist is Map) {
          return byArtist['name']?.toString();
        }
      } catch (_) {}
    }
    return null;
  }

  static String parseHtmlToChordPro(String htmlContent, {int? targetKeyIndex}) {
    final document = html_parser.parse(htmlContent);

    // Extract Metadata using updated multi-fallback logic
    final meta = _extractMetadata(document);
    String originalKeyStr = meta.key;
    String title = meta.title;
    String artist = meta.artist;

    String finalKey = originalKeyStr;
    int steps = 0;

    if (targetKeyIndex != null) {
      final notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
      final notesAlt = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];
      
      final match = RegExp(r'^([CDEFGAB][#b]?)').firstMatch(originalKeyStr);
      final rootFrom = match?.group(1) ?? originalKeyStr;
      
      int originalIndexInNotes = notes.indexOf(rootFrom);
      if (originalIndexInNotes == -1) originalIndexInNotes = notesAlt.indexOf(rootFrom);

      if (originalIndexInNotes != -1) {
        int targetIndexInNotes = (targetKeyIndex + 9) % 12;
        steps = targetIndexInNotes - originalIndexInNotes;
        
        final cifraclubKeys = ['A', 'Bb', 'B', 'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab'];
        finalKey = cifraclubKeys[targetKeyIndex % 12];
        if (originalKeyStr.endsWith('m')) {
          finalKey += 'm';
        }
      }
    }

    // --- VIDEO URL ---
    String videoUrl = '';
    final iframe = document.querySelector('iframe[src*="youtube.com"]');
    if (iframe != null) {
      videoUrl = iframe.attributes['src'] ?? '';
    } else {
      final thumb = document.querySelector('[data-youtube-id]');
      if (thumb != null) {
        final ytId = thumb.attributes['data-youtube-id'];
        if (ytId != null && ytId.isNotEmpty) {
          videoUrl = 'https://www.youtube.com/watch?v=$ytId';
        }
      }
    }

    // --- EXTRACT CIFRA ---
    // New layout: <pre data-chord-content="true"> with <div class="kvMV"> inside
    // Old layout: <div class="cifra_cnt"> > <pre>
    dom.Element? preElement = document.querySelector('pre[data-chord-content="true"]');
    preElement ??= document.querySelector('.cifra_cnt pre');
    
    if (preElement == null) {
      throw Exception('Não foi possível encontrar o bloco de cifra na página. O site pode ter mudado sua estrutura.');
    }

    // Convert to ChordPro
    final chordProLines = <String>[];
    chordProLines.add('{title: $title}');
    chordProLines.add('{artist: $artist}');
    chordProLines.add('{key: $finalKey}');
    if (videoUrl.isNotEmpty) {
      chordProLines.add('{video: $videoUrl}');
    }
    chordProLines.add('{tempo: 70}'); // default tempo
    chordProLines.add('');

    // Detect which layout we're in:
    // New layout uses <div class="kvMV"> containers inside the <pre>
    final kvmvDivs = preElement.querySelectorAll('.kvMV');

    if (kvmvDivs.isNotEmpty) {
      // --- NEW LAYOUT PARSER ---
      // Each <div class="kvMV"> is one "row" containing chords on the SAME line as lyrics.
      // Structure: spaces + <b data-chord-name="X">X</b> interspersed with text nodes + newline + lyric text
      _parseNewLayout(kvmvDivs, chordProLines);
    } else {
      // --- OLD LAYOUT PARSER (fallback) ---
      final rawHtml = preElement.innerHtml;
      final lines = rawHtml.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('<b>') || line.contains('</b>')) {
          if (i + 1 < lines.length && !lines[i + 1].contains('<b>') && _stripHtmlTags(lines[i + 1]).trim().isNotEmpty) {
            final lyricLine = _stripHtmlTags(lines[i + 1]);
            final mergedLine = _mergeChordsAndLyrics(line, lyricLine);
            chordProLines.add(mergedLine);
            i++; // Skip the next line since we merged it
          } else {
            chordProLines.add(_convertChordLineToChordPro(line));
          }
        } else {
          chordProLines.add(_stripHtmlTags(line));
        }
      }
    }

    String finalContent = chordProLines.join('\n');
    if (steps != 0) {
      final regex = RegExp(r'\[(.*?)\]');
      finalContent = finalContent.replaceAllMapped(regex, (match) {
        final chord = match.group(1)!;
        return '[${ChordTransposer.transpose(chord, steps)}]';
      });
    }

    return finalContent;
  }

  /// Parses the new Cifra Club layout where each `<div class="kvMV">` contains
  /// a mix of chord `<b>` elements and plain text (lyrics) on the same line,
  /// separated by a newline character.
  static void _parseNewLayout(List<dom.Element> kvmvDivs, List<String> chordProLines) {
    for (final div in kvmvDivs) {
      // The raw inner HTML of the div contains something like:
      //   "       <b data-chord-name="Em7" ...>Em7</b>\nNós estamos aqui\n"
      // or just chord-only lines like:
      //   "[Intro] <b ...>Em7</b>  <b ...>C9</b>\n"
      final rawInner = div.innerHtml;

      // Split by newline to separate chord line from lyric line(s)
      final parts = rawInner.split('\n');

      // First part is always the chord/section-header line
      final chordPart = parts.isNotEmpty ? parts[0] : '';
      // Remaining non-empty parts are lyric lines
      final lyricParts = parts.length > 1
          ? parts.sublist(1).where((l) => l.trim().isNotEmpty).toList()
          : <String>[];

      final hasBoldChords = chordPart.contains('<b');

      if (hasBoldChords && lyricParts.isNotEmpty) {
        // Mixed: chord positioning + lyrics – merge them
        final lyricLine = lyricParts.first;
        final merged = _mergeChordsAndLyricsNew(chordPart, lyricLine);
        chordProLines.add(merged);
        // If there are additional lyric lines (rare), add them plain
        for (final extra in lyricParts.sublist(1)) {
          chordProLines.add(_stripHtmlTags(extra));
        }
      } else if (hasBoldChords) {
        // Chord-only line (e.g. [Intro] Em7  C9  G)
        chordProLines.add(_convertChordLineToChordProNew(chordPart));
      } else {
        // Plain lyric / section header line
        final text = _stripHtmlTags(chordPart);
        if (text.isNotEmpty) {
          chordProLines.add(text);
        }
        for (final lyric in lyricParts) {
          final lt = _stripHtmlTags(lyric);
          if (lt.isNotEmpty) chordProLines.add(lt);
        }
      }
    }
  }

  /// Converts a chord-only HTML line in the NEW format (with data-chord-name attributes)
  /// to ChordPro inline chord notation.
  static String _convertChordLineToChordProNew(String chordLineHtml) {
    // <b data-chord-name="Em7" ...>Em7</b> → [Em7]
    // Use data-chord-name attribute which is more reliable
    String result = chordLineHtml.replaceAllMapped(
      RegExp(r'<b\s[^>]*data-chord-name="([^"]+)"[^>]*>.*?</b>', dotAll: true),
      (m) => '[${m.group(1)}]',
    );
    // Fallback: plain <b>X</b>
    result = result.replaceAllMapped(RegExp(r'<b>(.*?)</b>'), (m) => '[${m.group(1)}]');
    // Strip any remaining HTML tags
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');
    return result;
  }

  /// Merges chord HTML line with a lyric line in the NEW layout.
  static String _mergeChordsAndLyricsNew(String chordLineHtml, String lyricLine) {
    final List<Map<String, dynamic>> chords = [];
    int visualPosition = 0;

    // Match <b data-chord-name="X" ...> or plain text/spaces
    final regex = RegExp(r'(<b\s[^>]*data-chord-name="([^"]+)"[^>]*>.*?</b>)|([^<]+)', dotAll: true);
    for (final match in regex.allMatches(chordLineHtml)) {
      if (match.group(1) != null) {
        // It's a chord element – use data-chord-name attribute
        final chordName = match.group(2)!;
        chords.add({'chord': chordName, 'pos': visualPosition});
        visualPosition += chordName.length;
      } else if (match.group(3) != null) {
        // Plain text (spaces between chords)
        visualPosition += match.group(3)!.length;
      }
    }

    // Strip HTML tags from lyric line
    String result = _stripHtmlTags(lyricLine);
    // Pad if lyric is shorter than the last chord position
    if (chords.isNotEmpty) {
      final maxPos = chords.last['pos'] as int;
      if (result.length < maxPos) {
        result = result.padRight(maxPos);
      }
    }

    // Insert chords from back to front to avoid index shifting
    for (var i = chords.length - 1; i >= 0; i--) {
      final chord = chords[i]['chord'] as String;
      final pos = chords[i]['pos'] as int;
      if (pos < result.length) {
        result = '${result.substring(0, pos)}[$chord]${result.substring(pos)}';
      } else {
        result += '[$chord]';
      }
    }

    return result;
  }

  static String _stripHtmlTags(String html) {
    final document = html_parser.parse(html);
    return document.body?.text ?? '';
  }

  // ---- OLD LAYOUT helpers (kept for fallback) ----

  static String _convertChordLineToChordPro(String chordLineHtml) {
    // Replace <b>C</b> with [C]
    return chordLineHtml
        .replaceAllMapped(RegExp(r'<b>(.*?)</b>'), (match) => '[${match.group(1)}]')
        .replaceAll(RegExp(r'<[^>]*>'), ''); // strip other tags
  }

  static String _mergeChordsAndLyrics(String chordLineHtml, String lyricLine) {
    List<Map<String, dynamic>> chords = [];
    int visualPosition = 0;
    
    final regex = RegExp(r'(<b>.*?</b>)|([^<]+)');
    for (final match in regex.allMatches(chordLineHtml)) {
      final text = match.group(0)!;
      if (text.startsWith('<b>')) {
        final chord = text.replaceAll('<b>', '').replaceAll('</b>', '');
        chords.add({'chord': chord, 'pos': visualPosition});
        visualPosition += chord.length;
      } else {
        visualPosition += text.length;
      }
    }

    String result = lyricLine;
    if (chords.isNotEmpty) {
      final maxPos = chords.last['pos'] as int;
      if (result.length < maxPos) {
        result = result.padRight(maxPos, ' ');
      }
    }

    for (var i = chords.length - 1; i >= 0; i--) {
      final chord = chords[i]['chord'] as String;
      final pos = chords[i]['pos'] as int;
      
      if (pos < result.length) {
        result = '${result.substring(0, pos)}[$chord]${result.substring(pos)}';
      } else {
        result += '[$chord]';
      }
    }

    return result;
  }
}
