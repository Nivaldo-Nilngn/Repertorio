import 'package:flutter/material.dart';
import '../models/chord_data.dart';

class UkuleleFretboardWidget extends StatelessWidget {
  final UkulelePosition position;
  final double width;
  final double height;
  final Color primaryColor;

  const UkuleleFretboardWidget({
    super.key,
    required this.position,
    this.width = 220,
    this.height = 280,
    this.primaryColor = const Color(0xFFE040FB), // Roxo neon
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E212D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _UkuleleFretboardPainter(
          position: position,
          primaryColor: primaryColor,
        ),
      ),
    );
  }
}

class _UkuleleFretboardPainter extends CustomPainter {
  final UkulelePosition position;
  final Color primaryColor;

  _UkuleleFretboardPainter({
    required this.position,
    required this.primaryColor,
  });

  static const int numStrings = 4;
  static const int numFrets = 5;

  @override
  void paint(Canvas canvas, Size size) {
    const double topMargin = 38.0;
    const double bottomMargin = 20.0;
    const double leftMargin = 36.0;
    const double rightMargin = 24.0;

    final double boardWidth = size.width - leftMargin - rightMargin;
    final double boardHeight = size.height - topMargin - bottomMargin;
    final double stringSpacing = boardWidth / (numStrings - 1);
    final double fretSpacing = boardHeight / numFrets;

    final baseFret = position.baseFret;
    final isFirstFret = baseFret == 1;

    // 1. Nut do Ukulele
    if (isFirstFret) {
      final nutPaint = Paint()..color = const Color(0xFFE8E5DA);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(leftMargin - 2, topMargin - 6, boardWidth + 4, 6),
          const Radius.circular(2),
        ),
        nutPaint,
      );
    } else {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$baseFretª',
          style: const TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 8, topMargin + fretSpacing * 0.3),
      );
    }

    // 2. Trastes
    final fretPaint = Paint()
      ..color = const Color(0xFF6B728E)
      ..strokeWidth = 2.0;

    for (int i = 0; i <= numFrets; i++) {
      final double y = topMargin + i * fretSpacing;
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(leftMargin + boardWidth, y),
        fretPaint,
      );
    }

    // Marcadores perolados (trastes 3 e 5)
    for (int i = 1; i <= numFrets; i++) {
      final int actualFret = baseFret + i - 1;
      if (actualFret == 3 || actualFret == 5 || actualFret == 7) {
        final double centerY = topMargin + (i - 0.5) * fretSpacing;
        final dotPaint = Paint()..color = Colors.white.withOpacity(0.12);
        canvas.drawCircle(Offset(leftMargin + boardWidth / 2, centerY), 4, dotPaint);
      }
    }

    // 3. 4 Cordas de Nylon
    final stringGauges = [1.8, 1.4, 1.6, 1.2]; // G, C, E, A
    for (int i = 0; i < numStrings; i++) {
      final double x = leftMargin + i * stringSpacing;
      final stringPaint = Paint()
        ..color = const Color(0xFFECEFF1)
        ..strokeWidth = stringGauges[i];

      canvas.drawLine(
        Offset(x, topMargin),
        Offset(x, topMargin + boardHeight),
        stringPaint,
      );
    }

    // 4. Marcadores de Cordas Soltas / Abafadas
    for (int i = 0; i < numStrings; i++) {
      final double x = leftMargin + i * stringSpacing;
      final int fretVal = i < position.frets.length ? position.frets[i] : -1;

      if (fretVal == -1) {
        final xPaint = TextPainter(
          text: const TextSpan(
            text: '×',
            style: TextStyle(
              color: Color(0xFFFF5252),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        xPaint.paint(canvas, Offset(x - xPaint.width / 2, topMargin - 28));
      } else if (fretVal == 0) {
        final oPaint = TextPainter(
          text: const TextSpan(
            text: '○',
            style: TextStyle(
              color: Color(0xFF00E676),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        oPaint.paint(canvas, Offset(x - oPaint.width / 2, topMargin - 26));
      }
    }

    // 5. Pestana
    if (position.barreFret != null && position.barreFret! >= baseFret) {
      final int relBarre = position.barreFret! - baseFret + 1;
      if (relBarre > 0 && relBarre <= numFrets) {
        final double y = topMargin + (relBarre - 0.5) * fretSpacing;
        final barrePaint = Paint()
          ..color = primaryColor.withOpacity(0.4)
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(leftMargin, y),
          Offset(leftMargin + boardWidth, y),
          barrePaint,
        );
      }
    }

    // 6. Bolinhas de Dedos
    for (int i = 0; i < numStrings; i++) {
      final int fretVal = i < position.frets.length ? position.frets[i] : -1;
      if (fretVal > 0) {
        final int relFret = fretVal - baseFret + 1;
        if (relFret > 0 && relFret <= numFrets) {
          final double x = leftMargin + i * stringSpacing;
          final double y = topMargin + (relFret - 0.5) * fretSpacing;

          final glowPaint = Paint()
            ..color = primaryColor.withOpacity(0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawCircle(Offset(x, y), 12, glowPaint);

          final dotPaint = Paint()..color = primaryColor;
          canvas.drawCircle(Offset(x, y), 9.5, dotPaint);

          final int fingerNum = i < position.fingers.length ? position.fingers[i] : 0;
          if (fingerNum > 0) {
            final fingerText = TextPainter(
              text: TextSpan(
                text: '$fingerNum',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            fingerText.paint(canvas, Offset(x - fingerText.width / 2, y - fingerText.height / 2));
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UkuleleFretboardPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.primaryColor != primaryColor;
  }
}
