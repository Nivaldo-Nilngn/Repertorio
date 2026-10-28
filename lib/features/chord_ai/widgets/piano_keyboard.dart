import 'package:flutter/material.dart';

class PianoKeyboardWidget extends StatelessWidget {
  final List<String> activeNotes; // ex: ['C', 'E', 'G']
  final double width;
  final double height;
  final Color activeColor;

  const PianoKeyboardWidget({
    super.key,
    required this.activeNotes,
    this.width = double.infinity,
    this.height = 140,
    this.activeColor = const Color(0xFFFF9100), // Âmbar neon
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: CustomPaint(
        painter: _PianoKeyboardPainter(
          activeNotes: activeNotes.map((n) => _normalizeNote(n)).toSet(),
          activeColor: activeColor,
        ),
      ),
    );
  }

  String _normalizeNote(String note) {
    const map = {
      'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
    };
    return map[note] ?? note;
  }
}

class _PianoKeyboardPainter extends CustomPainter {
  final Set<String> activeNotes;
  final Color activeColor;

  _PianoKeyboardPainter({
    required this.activeNotes,
    required this.activeColor,
  });

  // 2 oitavas completas (14 teclas brancas)
  static const List<String> whiteKeyNotes = [
    'C', 'D', 'E', 'F', 'G', 'A', 'B',
    'C', 'D', 'E', 'F', 'G', 'A', 'B',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final int numWhiteKeys = whiteKeyNotes.length;
    final double whiteKeyWidth = size.width / numWhiteKeys;
    final double whiteKeyHeight = size.height;
    final double blackKeyWidth = whiteKeyWidth * 0.62;
    final double blackKeyHeight = whiteKeyHeight * 0.62;

    // 1. Desenha teclas brancas
    for (int i = 0; i < numWhiteKeys; i++) {
      final String noteName = whiteKeyNotes[i];
      final bool isActive = activeNotes.contains(noteName);
      final double x = i * whiteKeyWidth;

      final Rect keyRect = Rect.fromLTWH(x + 1, 0, whiteKeyWidth - 2, whiteKeyHeight);
      final RRect rrect = RRect.fromRectAndCorners(
        keyRect,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );

      final keyPaint = Paint()
        ..color = isActive ? activeColor.withOpacity(0.85) : const Color(0xFFF0F2F5)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, keyPaint);

      // Borda sutil
      final borderPaint = Paint()
        ..color = const Color(0xFF2C3246)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rrect, borderPaint);

      // Rótulo da nota ativa
      if (isActive) {
        final tp = TextPainter(
          text: TextSpan(
            text: noteName,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + (whiteKeyWidth - tp.width) / 2, whiteKeyHeight - 20));
      }
    }

    // 2. Desenha teclas pretas (C#, D#, F#, G#, A# nas duas oitavas)
    final blackKeyOffsets = [
      (0, 'C#'), (1, 'D#'), (3, 'F#'), (4, 'G#'), (5, 'A#'),
      (7, 'C#'), (8, 'D#'), (10, 'F#'), (11, 'G#'), (12, 'A#'),
    ];

    for (final (whiteIndex, noteName) in blackKeyOffsets) {
      final bool isActive = activeNotes.contains(noteName);
      final double x = (whiteIndex + 1) * whiteKeyWidth - (blackKeyWidth / 2);

      final Rect keyRect = Rect.fromLTWH(x, 0, blackKeyWidth, blackKeyHeight);
      final RRect rrect = RRect.fromRectAndCorners(
        keyRect,
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );

      // Sombra da tecla preta
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

      final keyPaint = Paint()
        ..color = isActive ? activeColor : const Color(0xFF1E2028)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, keyPaint);

      if (isActive) {
        final tp = TextPainter(
          text: TextSpan(
            text: noteName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + (blackKeyWidth - tp.width) / 2, blackKeyHeight - 16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PianoKeyboardPainter oldDelegate) {
    return oldDelegate.activeNotes != activeNotes || oldDelegate.activeColor != activeColor;
  }
}
