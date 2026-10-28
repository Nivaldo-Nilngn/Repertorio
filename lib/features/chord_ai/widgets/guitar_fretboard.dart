import 'package:flutter/material.dart';
import '../models/chord_data.dart';

class GuitarFretboardWidget extends StatelessWidget {
  final GuitarPosition position;
  final double width;
  final double height;
  final Color primaryColor;

  const GuitarFretboardWidget({
    super.key,
    required this.position,
    this.width = 240,
    this.height = 300,
    this.primaryColor = const Color(0xFF00E5FF), // Ciano neon
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E212D), // Madeira escura moderna
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
        painter: _GuitarFretboardPainter(
          position: position,
          primaryColor: primaryColor,
        ),
      ),
    );
  }
}

class _GuitarFretboardPainter extends CustomPainter {
  final GuitarPosition position;
  final Color primaryColor;

  _GuitarFretboardPainter({
    required this.position,
    required this.primaryColor,
  });

  static const int numStrings = 6;
  static const int numFrets = 5; // Mostra 5 trastes visíveis

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = (size.width / 220.0).clamp(0.55, 1.2);
    final double topMargin = 32.0 * scale;
    final double bottomMargin = 14.0 * scale;
    final double leftMargin = 28.0 * scale;
    final double rightMargin = 18.0 * scale;

    final double boardWidth = size.width - leftMargin - rightMargin;
    final double boardHeight = size.height - topMargin - bottomMargin;
    final double stringSpacing = boardWidth / (numStrings - 1);
    final double fretSpacing = boardHeight / numFrets;

    final baseFret = position.baseFret;
    final isFirstFret = baseFret == 1;

    // 1. Nut (Pestana superior de osso se for na casa 1)
    if (isFirstFret) {
      final nutPaint = Paint()
        ..color = const Color(0xFFE8E5DA)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(leftMargin - 2, topMargin - 5 * scale, boardWidth + 4, 5 * scale),
          Radius.circular(2 * scale),
        ),
        nutPaint,
      );
    } else {
      // Exibe o número da casa lateral (ex: "3ª casa")
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$baseFretª',
          style: TextStyle(
            color: const Color(0xFFFFD54F),
            fontSize: (13 * scale).clamp(9.0, 14.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 4, topMargin + fretSpacing * 0.3),
      );
    }

    // 2. Trastes de metal (linhas horizontais)
    final fretPaint = Paint()
      ..color = const Color(0xFF6B728E)
      ..strokeWidth = (1.8 * scale).clamp(1.0, 2.0);

    for (int i = 0; i <= numFrets; i++) {
      final double y = topMargin + i * fretSpacing;
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(leftMargin + boardWidth, y),
        fretPaint,
      );
    }

    // Marcadores perolados (bolinhas nos trastes 3, 5, 7, 9)
    for (int i = 1; i <= numFrets; i++) {
      final int actualFret = baseFret + i - 1;
      if (actualFret == 3 || actualFret == 5 || actualFret == 7 || actualFret == 9) {
        final double centerY = topMargin + (i - 0.5) * fretSpacing;
        final dotPaint = Paint()..color = Colors.white.withOpacity(0.12);
        canvas.drawCircle(Offset(leftMargin + boardWidth / 2, centerY), 3.5 * scale, dotPaint);
      }
    }

    // 3. Cordas (verticais com espessuras da 6ª à 1ª)
    final stringGauges = [2.5 * scale, 2.0 * scale, 1.6 * scale, 1.2 * scale, 1.0 * scale, 0.8 * scale];
    for (int i = 0; i < numStrings; i++) {
      final double x = leftMargin + i * stringSpacing;
      final gauge = stringGauges[i].clamp(0.6, 3.0);
      final stringPaint = Paint()
        ..color = (i < 3) ? const Color(0xFFD4AF37) : const Color(0xFFB0BEC5)
        ..strokeWidth = gauge;

      canvas.drawLine(
        Offset(x, topMargin),
        Offset(x, topMargin + boardHeight),
        stringPaint,
      );
    }

    // 4. Marcadores de Cordas Soltas / Abafadas acima do Nut (X e O)
    for (int i = 0; i < numStrings; i++) {
      final double x = leftMargin + i * stringSpacing;
      final int fretVal = i < position.frets.length ? position.frets[i] : -1;

      if (fretVal == -1) {
        // 'X' (corda abafada)
        final xPaint = TextPainter(
          text: TextSpan(
            text: '×',
            style: TextStyle(
              color: const Color(0xFFFF5252),
              fontSize: (15 * scale).clamp(10.0, 18.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        xPaint.paint(canvas, Offset(x - xPaint.width / 2, topMargin - 22 * scale));
      } else if (fretVal == 0) {
        // 'O' (corda solta)
        final oPaint = TextPainter(
          text: TextSpan(
            text: '○',
            style: TextStyle(
              color: const Color(0xFF00E676),
              fontSize: (14 * scale).clamp(9.0, 16.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        oPaint.paint(canvas, Offset(x - oPaint.width / 2, topMargin - 20 * scale));
      }
    }

    // 5. Pestana (Barre)
    if (position.barreFret != null && position.barreFret! >= baseFret) {
      final int relativeBarre = position.barreFret! - baseFret + 1;
      if (relativeBarre > 0 && relativeBarre <= numFrets) {
        final double y = topMargin + (relativeBarre - 0.5) * fretSpacing;

        int minString = 0;
        int maxString = 5;
        for (int i = 0; i < numStrings; i++) {
          if (position.frets[i] == position.barreFret) {
            minString = i;
            break;
          }
        }
        for (int i = numStrings - 1; i >= 0; i--) {
          if (position.frets[i] == position.barreFret) {
            maxString = i;
            break;
          }
        }

        final double x1 = leftMargin + minString * stringSpacing;
        final double x2 = leftMargin + maxString * stringSpacing;

        final barrePaint = Paint()
          ..color = primaryColor.withOpacity(0.4)
          ..strokeWidth = 14 * scale
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(Offset(x1, y), Offset(x2, y), barrePaint);
      }
    }

    // 6. Bolinhas de Dedos nos trastes
    for (int i = 0; i < numStrings; i++) {
      final int fretVal = i < position.frets.length ? position.frets[i] : -1;
      if (fretVal > 0) {
        final int relFret = fretVal - baseFret + 1;
        if (relFret > 0 && relFret <= numFrets) {
          final double x = leftMargin + i * stringSpacing;
          final double y = topMargin + (relFret - 0.5) * fretSpacing;

          // Efeito Glow ao redor do dedo
          final glowPaint = Paint()
            ..color = primaryColor.withOpacity(0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * scale);
          canvas.drawCircle(Offset(x, y), 10 * scale, glowPaint);

          // Ponto principal
          final dotPaint = Paint()..color = primaryColor;
          canvas.drawCircle(Offset(x, y), 8 * scale, dotPaint);

          // Número do dedo
          final int fingerNum = i < position.fingers.length ? position.fingers[i] : 0;
          if (fingerNum > 0) {
            final fingerText = TextPainter(
              text: TextSpan(
                text: '$fingerNum',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: (9.5 * scale).clamp(7.0, 12.0),
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
  bool shouldRepaint(covariant _GuitarFretboardPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.primaryColor != primaryColor;
  }
}
