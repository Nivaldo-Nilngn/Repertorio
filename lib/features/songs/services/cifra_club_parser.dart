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

    final proxyUrl = '$_proxyBaseUrl?url=' + Uri.encodeComponent(url);
    try {
      final response = await http.get(Uri.parse(proxyUrl));
      if (response.statusCode == 200) {
        final htmlContent = response.body;
        if (url.toLowerCase().contains('bananacifras')) {
          return await BananaCifrasParser.parseHtmlToChordPro(htmlContent, targetKeyIndex: targetKeyIndex);
        }
        return parseHtmlToChordPro(htmlContent, targetKeyIndex: targetKeyIndex);
      }
      throw Exception('Failed to fetch page');
    } catch (e) {
      throw Exception('Error parsing URL: $e');
    }
  }

  static String parseHtmlToChordPro(String htmlContent, {int? targetKeyIndex}) {
    final document = html_parser.parse(htmlContent);

    // Extract Metadata
    final titleElement = document.querySelector('.t1');
    final artistElement = document.querySelector('.t3');
    final keyElement = document.querySelector('#cifra_tom a');

    final title = titleElement?.text.trim() ?? 'Unknown Title';
    final artist = artistElement?.text.trim() ?? 'Unknown Artist';
    
    String originalKeyStr = keyElement?.text.trim() ?? 'C';
    final tomContent = document.querySelector('#cifra_tom')?.text ?? '';
    final formaMatch = RegExp(r'forma dos acordes no tom de ([CDEFGAB][#b]?m?)', caseSensitive: false).firstMatch(tomContent);
    if (formaMatch != null) {
      originalKeyStr = formaMatch.group(1)!;
    }

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

    // Extract Cifra (Pre block)
    final preElement = document.querySelector('.cifra_cnt pre');
    if (preElement == null) {
      throw Exception('Could not find the lyrics/chords block.');
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

    // To parse properly, we need to read the raw HTML inside the <pre> tag,
    // where chords are in <b> tags.
    final rawHtml = preElement.innerHtml;
    // Split by newlines
    final lines = rawHtml.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // A simple heuristic: if a line has <b> tags, it's likely a chord line.
      // Cifra Club puts chords in <b> tags. e.g. <b>C</b>
      if (line.contains('<b>') || line.contains('</b>')) {
        // We will try to merge this chord line with the next lyric line
        // Only merge if the next line is NOT empty!
        if (i + 1 < lines.length && !lines[i + 1].contains('<b>') && _stripHtmlTags(lines[i + 1]).trim().isNotEmpty) {
          final lyricLine = _stripHtmlTags(lines[i + 1]);
          final mergedLine = _mergeChordsAndLyrics(line, lyricLine);
          chordProLines.add(mergedLine);
          i++; // Skip the next line since we merged it
        } else {
          // If the next line is also a chord line or there are no more lines, just output the chords inline
          chordProLines.add(_convertChordLineToChordPro(line));
        }
      } else {
        // Just a normal lyric line
        chordProLines.add(_stripHtmlTags(line));
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

  static String _stripHtmlTags(String html) {
    final document = html_parser.parse(html);
    return document.body?.text ?? '';
  }

  static String _convertChordLineToChordPro(String chordLineHtml) {
    // Replace <b>C</b> with [C]
    return chordLineHtml
        .replaceAllMapped(RegExp(r'<b>(.*?)</b>'), (match) => '[${match.group(1)}]')
        .replaceAll(RegExp(r'<[^>]*>'), ''); // strip other tags
  }

  static String _mergeChordsAndLyrics(String chordLineHtml, String lyricLine) {
    // This is a naive merge. We find the index of each <b> tag, 
    // extract the chord, and insert it into the lyric string at that visual index.
    
    // First, let's find all chords and their visual positions in the chord line.
    // We strip tags to find visual position, but we need to track where the tags were.
    
    List<Map<String, dynamic>> chords = [];
    int visualPosition = 0;
    
    // Regex to match either a <b>chord</b> or text
    final regex = RegExp(r'(<b>.*?</b>)|([^<]+)');
    for (final match in regex.allMatches(chordLineHtml)) {
      final text = match.group(0)!;
      if (text.startsWith('<b>')) {
        final chord = text.replaceAll('<b>', '').replaceAll('</b>', '');
        chords.add({'chord': chord, 'pos': visualPosition});
        visualPosition += chord.length;
      } else {
        // just spaces or text
        visualPosition += text.length;
      }
    }

    // Now insert the chords into the lyric line from back to front to avoid index shifting
    String result = lyricLine;
    // Pad the lyric line if it's too short
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
        result = result.substring(0, pos) + '[$chord]' + result.substring(pos);
      } else {
        result += '[$chord]';
      }
    }

    return result;
  }
}
