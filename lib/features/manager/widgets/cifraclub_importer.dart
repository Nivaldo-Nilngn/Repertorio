import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../songs/models/song.dart';
import '../../songs/repositories/song_repository.dart';
import '../../songs/services/cifra_club_parser.dart';

const List<String> _urlsToImport = [
  'https://www.cifraclub.com.br/julliany-souza/ah-jesus-coracao-igual-ao-teu-2-2/#tabs=false&instrument=keyboard&key=3',
  'https://www.cifraclub.com.br/gabriela-rocha/atos-2/#key=5',
  'https://www.cifraclub.com.br/diante-do-trono/aclame-ao-senhor/#key=8',
  'https://www.cifraclub.com.br/fernanda-brum/o-que-tua-gloria-fez-comigo/',
  'https://www.cifraclub.com.br/cassiane/amigo-espirito-santo/#key=8',
  'https://www.cifraclub.com.br/gabriel-guedes/outro-igual-nao-ha-ao-rei-nos-coroamos/#key=7',
  'https://www.cifraclub.com.br/jose-augusto-five-music/yeshua/#key=7',
  'https://www.cifraclub.com.br/adhemar-de-campos/o-nosso-general-e-cristo/#key=9',
  'https://www.cifraclub.com.br/family-worship/em-teu-nome/',
  'https://www.cifraclub.com.br/laura-souguellis/em-teus-bracos/',
  'https://www.cifraclub.com.br/felipe-rodrigues/melhor-lugar/#capo=0&key=7',
  'https://www.cifraclub.com.br/eula-cris/acima-das-estrelas/#key=7',
  'https://www.cifraclub.com.br/kaleb-e-josh/te-seguirei-ate-o-fim/',
  'https://www.cifraclub.com.br/o-canto-das-igrejas/tu-es-deus-a-ele/#key=8',
  'https://www.cifraclub.com.br/gabi-sampaio/ambicao-part-som-do-ceu-thiago-henrique-e-marllon-ribeiro/#key=7',
  'https://www.cifraclub.com.br/florianopolis-house-of-prayer/dono-da-minha-afeicao/#key=8',
  'https://www.cifraclub.com.br/aline-barros/vitoria-no-deserto/#key=7',
  'https://www.cifraclub.com.br/adhemar-de-campos/grande-o-senhor/#key=7',
  'https://www.cifraclub.com.br/comunidade-da-zona-sul/rompendo-em-fe/#key=3',
  'https://www.cifraclub.com.br/nivea-soares/que-se-abra-os-ceus/',
  'https://www.cifraclub.com.br/aline-barros/jeova-jireh/#key=0',
  'https://www.cifraclub.com.br/get-worship/sou-grato-por-seu-amor/',
  'https://www.cifraclub.com.br/gabriela-rocha/oh-quao-lindo-esse-nome-e-so-tu-es-santo-pra-te-adorar-medley/#key=5',
  'https://www.cifraclub.com.br/sede-verbo-da-vida/eu-te-agradeco/#key=7',
  'https://www.cifraclub.com.br/nicolly-sena/me-ama-nao-ha-outro/#key=7',
  'https://www.cifraclub.com.br/harpa-crista/porque-ele-vive/#key=5',
  'https://www.cifraclub.com.br/gabriel-rodrigues-2/eu-pego-o-que-e-meu/#key=4',
  'https://www.cifraclub.com.br/get-worship/um-novo-dia/#capo=0',
  'https://www.cifraclub.com.br/sarah-farias/se-eu-nao-te-ouvir/',
  'https://www.cifraclub.com.br/oasis-ministry/yahweh-se-manifestara-pt-br/',
  'https://www.cifraclub.com.br/gabriel-guedes/a-bencao/#key=0',
  'https://www.cifraclub.com.br/toque-no-altar/olha-pra-mim/#key=7',
  'https://www.cifraclub.com.br/theo-rubia/eu-so-quero-tua-presenca/',
  'https://www.cifraclub.com.br/kleber-lucas/meu-alvo/#key=0',
  'https://www.cifraclub.com.br/florianopolis-house-of-prayer/gratidao/#capo=0&key=3',
  'https://www.cifraclub.com.br/gabriela-rocha/meu-respirar-meu-prazer-pot-pourri/#capo=0',
];

class CifraClubImporterBtn extends ConsumerStatefulWidget {
  const CifraClubImporterBtn({super.key});

  @override
  ConsumerState<CifraClubImporterBtn> createState() => _CifraClubImporterBtnState();
}

class _CifraClubImporterBtnState extends ConsumerState<CifraClubImporterBtn> {
  bool _isImporting = false;
  int _progress = 0;
  int _total = 0;

  Future<void> _startImport() async {
    setState(() {
      _isImporting = true;
      _total = _urlsToImport.length;
      _progress = 0;
    });

    final repo = ref.read(songRepositoryProvider);

    for (final url in _urlsToImport) {
      try {
        final chordPro = await CifraClubParser.fetchAndParse(url);
        
        String title = 'Música Importada';
        String artist = 'Artista';
        String key = 'C';

        for (final line in chordPro.split('\n')) {
          if (line.startsWith('{title:')) {
            title = line.replaceAll('{title:', '').replaceAll('}', '').trim();
          } else if (line.startsWith('{artist:')) {
            artist = line.replaceAll('{artist:', '').replaceAll('}', '').trim();
          } else if (line.startsWith('{key:')) {
            key = line.replaceAll('{key:', '').replaceAll('}', '').trim();
          }
        }

        final song = Song(
          id: DateTime.now().millisecondsSinceEpoch.toString() + _progress.toString(),
          title: title,
          artist: artist,
          key: key,
          bpm: 70,
          content: chordPro,
        );

        await repo.createSong(song);
      } catch (e) {
        print('Erro ao importar $url: $e');
      }

      if (mounted) {
        setState(() {
          _progress++;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isImporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importação concluída! $_progress músicas importadas.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isImporting) {
      return TextButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('$_progress / $_total'),
      );
    }

    return TextButton.icon(
      onPressed: _startImport,
      icon: const Icon(Icons.cloud_download, size: 16),
      label: const Text('Importar CifraClub'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.orange,
      ),
    );
  }
}
