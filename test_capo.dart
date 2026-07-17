import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  final url = 'https://cifra-proxy.nivaldo-nilngn.workers.dev?url=https://www.cifraclub.com.br/get-worship/um-novo-dia/';
  final response = await http.get(Uri.parse(url));
  final document = html_parser.parse(response.body);
  
  print("TOM A: " + (document.querySelector('#cifra_tom a')?.text ?? ''));
  print("TOM CONTENT: " + (document.querySelector('#cifra_tom')?.text ?? ''));
  print("CAPO: " + (document.querySelector('#cifra_capo')?.text ?? ''));
  
  // also look for span containing "forma"
  final allSpans = document.querySelectorAll('span');
  for (var span in allSpans) {
    if (span.text.contains('forma dos acordes') || span.text.contains('Capotraste')) {
      print("Found span: " + span.text);
    }
  }
}
