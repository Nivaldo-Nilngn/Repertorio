import 'dart:math';
import 'package:flutter/material.dart';

class ChordMarker {
  final double second;
  final String chord;

  ChordMarker(this.second, this.chord);
}

class ScrollingWaveformTimeline extends StatelessWidget {
  final double currentSeconds;
  final double totalSeconds;
  final List<ChordMarker> chordMarkers;
  final String keySignature;
  final int bpm;
  final ValueChanged<double>? onSeek;

  const ScrollingWaveformTimeline({
    super.key,
    required this.currentSeconds,
    required this.totalSeconds,
    required this.chordMarkers,
    this.keySignature = 'C',
    this.bpm = 120,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 125,
      decoration: const BoxDecoration(
        color: Color(0xFF0C101B),
      ),
      child: Stack(
        children: [
          // 1. Linha do Tempo e Waveform Rolável
          Positioned.fill(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (onSeek != null && totalSeconds > 0) {
                  // Cada pixel equivale a ~0.08 segundos
                  final newSec = (currentSeconds - details.primaryDelta! * 0.08)
                      .clamp(0.0, totalSeconds);
                  onSeek!(newSec);
                }
              },
              child: CustomPaint(
                painter: _WaveformTimelinePainter(
                  currentSeconds: currentSeconds,
                  totalSeconds: totalSeconds,
                  chordMarkers: chordMarkers,
                ),
              ),
            ),
          ),

          // 2. Cursor Central Branco Fixo (como no Chord ai)
          Center(
            child: Container(
              width: 2.0,
              height: double.infinity,
              color: Colors.white,
            ),
          ),

          // 3. Badges Inferiores: Key (Tom) à esquerda, BPM à direita
          Positioned(
            left: 12,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE88A6E), // Tom pêssego/laranja idêntico ao Chord ai
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Key: $keySignature',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          Positioned(
            right: 12,
            bottom: 6,
            child: Text(
              'BPM: $bpm',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformTimelinePainter extends CustomPainter {
  final double currentSeconds;
  final double totalSeconds;
  final List<ChordMarker> chordMarkers;

  _WaveformTimelinePainter({
    required this.currentSeconds,
    required this.totalSeconds,
    required this.chordMarkers,
  });

  static const double pixelsPerSecond = 55.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    const double tickHeight = 6.0;
    const double topMargin = 22.0;

    // 1. Ticks de tempo e segundos (ex: 0:27, 0:28, 0:29)
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.4),
      fontSize: 10,
    );

    final int startSec = max(0, (currentSeconds - (centerX / pixelsPerSecond)).floor() - 1);
    final int endSec = (currentSeconds + (centerX / pixelsPerSecond)).ceil() + 1;

    for (int sec = startSec; sec <= endSec; sec++) {
      final double x = centerX + (sec - currentSeconds) * pixelsPerSecond;
      if (x < -50 || x > size.width + 50) continue;

      // Linha vertical do segundo
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, tickHeight),
        Paint()..color = Colors.white.withOpacity(0.2)..strokeWidth = 1.0,
      );

      // Texto do tempo (ex: "0:28")
      final m = sec ~/ 60;
      final s = (sec % 60).toString().padLeft(2, '0');
      final tp = TextPainter(
        text: TextSpan(text: '$m:$s', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, tickHeight + 2));
    }

    // 2. Waveform (Barras verticais simulando amplitude de áudio)
    final double waveCenterY = size.height * 0.62;
    final int totalBars = (size.width / 4.0).toInt();

    for (int i = 0; i < totalBars; i++) {
      final double x = i * 4.0;
      final double secAtX = currentSeconds + (x - centerX) / pixelsPerSecond;

      // Altura da onda baseada em pseudo-ruído determinístico suave
      final double hash = sin(secAtX * 14.5) * 0.5 + sin(secAtX * 2.3) * 0.3 + cos(secAtX * 7.7) * 0.2;
      final double barHeight = max(4.0, (hash.abs() * 32.0));

      final barPaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, waveCenterY - barHeight / 2),
        Offset(x, waveCenterY + barHeight / 2),
        barPaint,
      );
    }

    // 3. Tags de Acordes posicionados na linha do tempo acima da onda
    for (final marker in chordMarkers) {
      final double x = centerX + (marker.second - currentSeconds) * pixelsPerSecond;
      if (x < -80 || x > size.width + 80) continue;

      // Caixa do acorde (estilo Chord ai: bege/creme com borda arredondada)
      final chordTp = TextPainter(
        text: TextSpan(
          text: marker.chord,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, topMargin + 15),
          width: chordTp.width + 16,
          height: 22,
        ),
        const Radius.circular(5),
      );

      // Fundo bege do acorde
      canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFFEFE9DB));
      chordTp.paint(canvas, Offset(x - chordTp.width / 2, topMargin + 15 - chordTp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformTimelinePainter oldDelegate) {
    return oldDelegate.currentSeconds != currentSeconds ||
        oldDelegate.chordMarkers != chordMarkers;
  }
}
