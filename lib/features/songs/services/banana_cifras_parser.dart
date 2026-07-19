import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:musicifras/features/songs/utils/chord_converter_utility.dart';
import 'package:musicifras/features/songs/utils/chord_transposer.dart';

class BananaCifrasParser {
  static const String _proxyBaseUrl = 'https://cifra-proxy.nivaldo-nilngn.workers.dev';

  static Future<String> parseHtmlToChordPro(String htmlContent, {int? targetKeyIndex}) async {
    // Extract songdata JSON from HTML
    final regex = RegExp(r'songdata=(\{.*?\})');
    final match = regex.firstMatch(htmlContent);
    if (match == null) {
      throw Exception('Não foi possível encontrar os dados da música no Banana Cifras.');
    }
    
    final songDataJson = json.decode(match.group(1)!);
    final title = songDataJson['track_name'] ?? 'Unknown Title';
    final artist = songDataJson['artist_name'] ?? 'Unknown Artist';
    final tabId = songDataJson['tab_id'];
    
    if (tabId == null) {
      throw Exception('ID da cifra não encontrado.');
    }
    
    // Fetch actual tab JSON
    final tabUrl = 'https://www.bananacifras.com/json/tab.js?id=$tabId';
    final tabProxyUrl = '$_proxyBaseUrl?url=' + Uri.encodeComponent(tabUrl);
    final tabResponse = await http.get(Uri.parse(tabProxyUrl));
    
    if (tabResponse.statusCode != 200) {
      throw Exception('Falha ao carregar a cifra do Banana Cifras.');
    }
    
    final tabDataJson = json.decode(tabResponse.body);
    final originalKeyStr = tabDataJson['tone'] ?? 'C';
    final content = tabDataJson['content'] ?? '';
    
    int steps = 0;
    String finalKey = originalKeyStr;

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
    
    // Use the ChordConverterUtility to convert the raw content to ChordPro
    final convertedChords = ChordConverterUtility.convertStandardToChordPro(content);
    
    // Build final ChordPro
    final chordProLines = <String>[];
    chordProLines.add('{title: $title}');
    chordProLines.add('{artist: $artist}');
    chordProLines.add('{key: $finalKey}');
    chordProLines.add('{tempo: 70}');
    chordProLines.add('');
    chordProLines.add(convertedChords);
    
    String finalContent = chordProLines.join('\n');

    if (steps != 0) {
      final chordRegex = RegExp(r'\[(.*?)\]');
      finalContent = finalContent.replaceAllMapped(chordRegex, (match) {
        final chord = match.group(1)!;
        // Verify if it's a valid chord before transposing to avoid transposing section names like [Primeira Parte]
        if (chord.length <= 10 && RegExp(r'^[A-G]').hasMatch(chord)) {
          return '[${ChordTransposer.transpose(chord, steps)}]';
        }
        return '[${chord}]';
      });
    }

    return finalContent;
  }
}
