import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/audio_js_interop.dart' as js_audio;

class AdvancedAudioPlayerUI extends StatefulWidget {
  final String title;
  final String artist;
  final String youtubeUrl; // e.g., https://www.youtube.com/watch?v=...
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final Future<void> Function()? onAudioLoaded;

  const AdvancedAudioPlayerUI({
    Key? key,
    required this.title,
    required this.artist,
    required this.youtubeUrl,
    this.onPlay,
    this.onPause,
    this.onAudioLoaded,
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

        js_audio.initAudioPlayer(b2Url, () async {
          if (mounted) {
            setState(() {
              _statusMessage = 'Analisando acordes...';
            });
            if (widget.onAudioLoaded != null) {
              await widget.onAudioLoaded!();
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
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
      if (widget.onPlay != null) widget.onPlay!();
    } else {
      js_audio.pauseAudio();
      if (widget.onPause != null) widget.onPause!();
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
      elevation: 0,
      color: Colors.transparent, // Background handled by parent
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail / Icon
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.music_note, color: Colors.greenAccent, size: 32),
            ),
            const SizedBox(width: 16),
            
            // Title & Artist
            Expanded(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(widget.artist, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            
            // Sliders
            Expanded(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Transpose
                  _buildCompactSliderControl(
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
                  // Speed
                  _buildCompactSliderControl(
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
                ],
              ),
            ),
            
            // Playback Controls
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.fast_rewind, color: Colors.white70),
                    onPressed: () {
                      final curr = js_audio.getAudioProgress();
                      js_audio.seekAudio(curr > 15 ? curr - 15 : 0);
                    },
                  ),
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent,
                      ),
                      child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 28),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fast_forward, color: Colors.white70),
                    onPressed: () {
                      final curr = js_audio.getAudioProgress();
                      js_audio.seekAudio(curr + 15);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.greenAccent,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(width: 50, child: Text(displayValue, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ],
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
