import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/audio_js_interop.dart' as js_audio;

class AdvancedAudioPlayerUI extends StatefulWidget {
  final String title;
  final String artist;
  final String youtubeUrl; // e.g., https://www.youtube.com/watch?v=...

  const AdvancedAudioPlayerUI({
    Key? key,
    required this.title,
    required this.artist,
    required this.youtubeUrl,
  }) : super(key: key);

  @override
  State<AdvancedAudioPlayerUI> createState() => _AdvancedAudioPlayerUIState();
}

class _AdvancedAudioPlayerUIState extends State<AdvancedAudioPlayerUI> {
  bool _isLoading = true;
  bool _isPlaying = false;
  String _statusMessage = 'Preparando áudio de alta qualidade...';
  
  double _pitch = 0.0;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchAndInitAudio();
  }

  Future<void> _fetchAndInitAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Baixando áudio no servidor...';
      });

      final response = await http.post(
        Uri.parse('http://localhost:3000/api/download'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'youtubeUrl': widget.youtubeUrl}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final b2Url = data['url'];
        
        setState(() {
          _statusMessage = 'Carregando engine de áudio...';
        });

        js_audio.initAudioPlayer(b2Url, () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      } else {
        setState(() {
          _statusMessage = 'Erro no servidor: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Falha ao conectar no servidor local.\nExecute "node server.js"';
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      js_audio.playAudio();
    } else {
      js_audio.pauseAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Material(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.greenAccent),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF161616), // Dark premium background
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.music_note, color: Colors.greenAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(widget.artist, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Transpose / Pitch Control
            _buildSliderControl(
              label: 'Transpose / Pitch',
              value: _pitch,
              min: -12,
              max: 12,
              divisions: 24,
              displayValue: _pitch == 0 ? 'Original' : (_pitch > 0 ? '+${_pitch.toInt()}' : '${_pitch.toInt()}'),
              onChanged: (val) {
                setState(() => _pitch = val);
                js_audio.setPitch(val);
              },
            ),
            const SizedBox(height: 16),

            // Speed Control
            _buildSliderControl(
              label: 'Velocidade',
              value: _speed,
              min: 0.5,
              max: 1.5,
              displayValue: '${(_speed * 100).toInt()}%',
              onChanged: (val) {
                setState(() => _speed = val);
                js_audio.setSpeed(val);
              },
            ),
            const SizedBox(height: 24),

            // Playback Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.fast_rewind, color: Colors.white70),
                  onPressed: () {},
                ),
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.greenAccent,
                    ),
                    child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 32),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.fast_forward, color: Colors.white70),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(displayValue, style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.white60,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
