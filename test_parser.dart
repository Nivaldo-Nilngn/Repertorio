import 'package:musicifras/features/songs/utils/chord_pro_parser.dart';

void main() {
  print("Starting test");
  final chordPro = """
[INTRO / PRIMEIRA PARTE]
[Dm7] [A#9] [F] [F9/A]
[Dm7] [A#9] [F] [F9/A]
""";

  final parsed = ChordProParser.parse(chordPro);
  print("Parsed lines: " + parsed.lines.length.toString());
  final sections = SongRoadmapBuilder.build(parsed);
  print("Sections length: " + sections.length.toString());
  
  for (var section in sections) {
    print("Section: " + section.title);
    for (var row in section.rows) {
      print("  Row (rep: " + (row.repetition ?? "null") + "): " + row.measures.toString());
    }
  }
}
