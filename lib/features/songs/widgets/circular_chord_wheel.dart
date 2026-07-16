import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/harmonic_field_calculator.dart';

class CircularChordWheel extends StatelessWidget {
  final String currentKey;
  final Set<String> usedChords;
  final String? startingChord;

  const CircularChordWheel({
    super.key,
    required this.currentKey,
    required this.usedChords,
    this.startingChord,
  });

  static const List<String> majorKeys = [
    'C', 'G', 'D', 'A', 'E', 'B', 'Gb', 'Db', 'Ab', 'Eb', 'Bb', 'F'
  ];
  
  static const List<String> minorKeys = [
    'Am', 'Em', 'Bm', 'F#m', 'C#m', 'G#m', 'Ebm', 'Bbm', 'Fm', 'Cm', 'Gm', 'Dm'
  ];
  
  static const List<String> dimKeys = [
    'B°', 'F#°', 'C#°', 'G#°', 'D#°', 'A#°', 'F°', 'C°', 'G°', 'D°', 'A°', 'E°'
  ];

  int _getKeyIndex() {
    String k = HarmonicFieldCalculator.extractRootChord(currentKey);
    // Special handling for F# vs Gb
    if (k == 'F#') k = 'Gb';
    if (k == 'C#') k = 'Db';
    if (k == 'D#') k = 'Eb';
    if (k == 'G#') k = 'Ab';
    if (k == 'A#') k = 'Bb';
    
    int idx = majorKeys.indexOf(k);
    if (idx == -1) {
      idx = minorKeys.indexOf(k); // if passing minor key directly
    }
    return idx != -1 ? idx : 0;
  }

  bool _isMinorKey() {
    String k = HarmonicFieldCalculator.extractRootChord(currentKey);
    return majorKeys.indexOf(k) == -1 && minorKeys.indexOf(k) != -1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keyIndex = _getKeyIndex();
    final isMinorKey = _isMinorKey();

    return LayoutBuilder(
      builder: (context, constraints) {
        double size = math.min(constraints.maxWidth, constraints.maxHeight);
        if (size == double.infinity) {
          size = math.min(constraints.maxWidth, 600.0);
        } else {
          size = math.min(size, 600.0);
        }
        final wheelSize = size * 0.82;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.62, // Corta a parte de baixo da roda
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The rotating background wheel
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: -keyIndex / 12.0, 
                          end: -keyIndex / 12.0
                        ),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        builder: (context, rotationTurns, child) {
                          return SizedBox(
                            width: wheelSize,
                            height: wheelSize,
                            child: CustomPaint(
                              painter: _WheelBasePainter(
                                colors: colors,
                                usedChords: usedChords,
                                majorKeys: majorKeys,
                                minorKeys: minorKeys,
                                dimKeys: dimKeys,
                                rotationTurns: rotationTurns,
                                startingChord: startingChord,
                                isMinorKey: isMinorKey,
                                activeKeyIndex: keyIndex,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // The static mask (always at the top)
                      SizedBox(
                        width: wheelSize,
                        height: wheelSize,
                        child: CustomPaint(
                          painter: _WheelMaskPainter(colors: colors, isMinorKey: isMinorKey),
                        ),
                      ),
                      
                      // Key center label
                      Container(
                        width: wheelSize * 0.18,
                        height: wheelSize * 0.18,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.outline.withOpacity(0.3), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          currentKey,
                          style: TextStyle(
                            fontSize: wheelSize * 0.05,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Legenda Responsiva Embaixo
            const SizedBox(height: 24),
            Text(
              'FUNÇÕES HARMÔNICAS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                _buildLegendItem('🛋️', 'TÔNICA', 'Descanso', const Color(0xFF2196F3)),
                _buildLegendItem('🚶', 'SUBDOMINANTE', 'Movimento', const Color(0xFF4CAF50)),
                _buildLegendItem('🏎️', 'DOMINANTE', 'Tensão', const Color(0xFFFF9800)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String emoji, String title, String subtitle, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 17.0), // Pula o emoji e o gap
              child: Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WheelBasePainter extends CustomPainter {
  final ColorScheme colors;
  final Set<String> usedChords;
  final List<String> majorKeys;
  final List<String> minorKeys;
  final List<String> dimKeys;
  final double rotationTurns;
  final String? startingChord;
  final bool isMinorKey;
  final int activeKeyIndex;

  _WheelBasePainter({
    required this.colors,
    required this.usedChords,
    required this.majorKeys,
    required this.minorKeys,
    required this.dimKeys,
    required this.rotationTurns,
    this.startingChord,
    required this.isMinorKey,
    required this.activeKeyIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Radii for the 3 rings
    final rOuter = radius;
    final rMiddle = radius * 0.72;
    final rInner = radius * 0.44;
    final rHole = radius * 0.22;

    final paintBg = Paint()
      ..color = colors.surfaceContainerLowest
      ..style = PaintingStyle.fill;
      
    final paintLine = Paint()
      ..color = colors.outline.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw base circles
    canvas.drawCircle(center, rOuter, paintBg);
    canvas.drawCircle(center, rOuter, paintLine);
    canvas.drawCircle(center, rMiddle, paintLine);
    canvas.drawCircle(center, rInner, paintLine);
    canvas.drawCircle(center, rHole, paintLine);

    final double sliceAngle = (2 * math.pi) / 12;
    final double globalRotation = rotationTurns * 2 * math.pi;

    for (int i = 0; i < 12; i++) {
      // Apply global rotation to the angles
      final angle = -math.pi / 2 + (i * sliceAngle) + (sliceAngle / 2) + globalRotation;
      
      final outerPoint = Offset(
        center.dx + rOuter * math.cos(angle),
        center.dy + rOuter * math.sin(angle),
      );
      final holePoint = Offset(
        center.dx + rHole * math.cos(angle),
        center.dy + rHole * math.sin(angle),
      );
      
      canvas.drawLine(holePoint, outerPoint, paintLine);

      // Determine if slice is in active window and function
      bool isCenter = i == activeKeyIndex;
      bool isLeft = i == (activeKeyIndex + 11) % 12; // Subdominant (IV)
      bool isRight = i == (activeKeyIndex + 1) % 12; // Dominant (V)
      
      bool isInActiveWindow = isCenter || isLeft || isRight;

      String majorDegree = '';
      String minorDegree = '';
      String dimDegree = '';

      if (isInActiveWindow) {
        if (isCenter) { 
          majorDegree = isMinorKey ? 'III' : 'I';
          minorDegree = isMinorKey ? 'I' : 'VI';
          dimDegree = isMinorKey ? 'II' : 'VII';
        }
        if (isLeft) { 
          majorDegree = isMinorKey ? 'VI' : 'IV';
          minorDegree = isMinorKey ? 'IV' : 'II';
        }
        if (isRight) { 
          majorDegree = isMinorKey ? 'VII' : 'V';
          minorDegree = isMinorKey ? 'V' : 'III';
        }
      }

      String displayMajor = majorKeys[i];
      String displayMinor = minorKeys[i];
      String displayDim = dimKeys[i];

      if (isInActiveWindow) {
        String? findExactChord(String rootKey) {
          for (String c in usedChords) {
            String cRoot = HarmonicFieldCalculator.extractRootChord(c);
            if (cRoot == rootKey || HarmonicFieldCalculator.areEnharmonicallyEquivalent(cRoot, rootKey)) {
              return c;
            }
          }
          return null;
        }

        displayMajor = findExactChord(majorKeys[i]) ?? majorKeys[i];
        displayMinor = findExactChord(minorKeys[i]) ?? minorKeys[i];
        displayDim = findExactChord(dimKeys[i]) ?? dimKeys[i];
      }

      // Draw text for this slice
      final textAngle = -math.pi / 2 + (i * sliceAngle) + globalRotation;
      
      _drawChordText(
        canvas: canvas, 
        center: center, 
        angle: textAngle, 
        chord: displayMajor, 
        radius: (rOuter + rMiddle) / 2, 
        sliceRadialHeight: rOuter - rMiddle,
        wheelSize: size.width,
        degreeLabel: majorDegree,
        isInActiveWindow: isInActiveWindow,
      );
      _drawChordText(
        canvas: canvas, 
        center: center, 
        angle: textAngle, 
        chord: displayMinor, 
        radius: (rMiddle + rInner) / 2, 
        sliceRadialHeight: rMiddle - rInner,
        wheelSize: size.width,
        degreeLabel: minorDegree,
        isInActiveWindow: isInActiveWindow,
      );
      _drawChordText(
        canvas: canvas, 
        center: center, 
        angle: textAngle, 
        chord: displayDim, 
        radius: (rInner + rHole) / 2, 
        sliceRadialHeight: rInner - rHole,
        wheelSize: size.width,
        degreeLabel: dimDegree,
        isInActiveWindow: isCenter, // inner ring is only active on the center slice (vii° or ii°)
      );
    }
  }

  void _drawChordText({
    required Canvas canvas, 
    required Offset center, 
    required double angle, 
    required String chord, 
    required double radius, 
    required double sliceRadialHeight,
    required double wheelSize,
    String? degreeLabel,
    bool isInActiveWindow = false,
  }) {
    final root = HarmonicFieldCalculator.extractRootChord(chord);
    final isUsed = usedChords.contains(root) || usedChords.contains(chord);
    
    final textPoint = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    // Se text estiver na metade inferior, gire-o para ficar legível
    double textRotation = angle + math.pi / 2;
    if (textRotation > math.pi / 2 && textRotation < 3 * math.pi / 2) {
      textRotation += math.pi;
    }

    final startingRoot = startingChord != null ? HarmonicFieldCalculator.extractRootChord(startingChord!) : null;
    final bool isStart = startingRoot != null && startingRoot == root;
    
    final double opacity = isInActiveWindow ? (isUsed ? 1.0 : 0.6) : 0.15;
    Color textColor = isInActiveWindow ? Colors.white.withOpacity(opacity) : colors.onSurfaceVariant.withOpacity(opacity);

    final List<TextSpan> children = [];
    
    children.add(TextSpan(
      text: chord,
      style: TextStyle(
        color: textColor,
        fontSize: wheelSize * 0.035,
        fontWeight: isUsed && isInActiveWindow ? FontWeight.bold : FontWeight.w500,
        shadows: isUsed && isInActiveWindow ? [
          Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)
        ] : null,
      ),
    ));

    if (isStart) {
      children.add(TextSpan(
        text: ' ▶',
        style: TextStyle(
          color: colors.tertiary.withOpacity(isInActiveWindow ? 1.0 : 0.4),
          fontSize: wheelSize * 0.025,
          fontWeight: FontWeight.bold,
        ),
      ));
    }

    final textSpan = TextSpan(children: children);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    TextPainter? degreePainter;
    if (degreeLabel != null && degreeLabel.isNotEmpty) {
      Color functionColor = colors.onSurfaceVariant.withOpacity(opacity);
      final dl = degreeLabel.toUpperCase();
      if (['I', 'III', 'VI'].contains(dl)) {
         functionColor = const Color(0xFF2196F3).withOpacity(opacity); // Blue
      } else if (['IV', 'II'].contains(dl)) {
         functionColor = const Color(0xFF4CAF50).withOpacity(opacity); // Green
      } else if (['V', 'VII'].contains(dl)) {
         functionColor = const Color(0xFFFF9800).withOpacity(opacity); // Orange
      }

      degreePainter = TextPainter(
        text: TextSpan(
          text: degreeLabel,
          style: TextStyle(
            color: functionColor,
            fontSize: wheelSize * 0.016, // Um pouco menor pra não brigar com o acorde
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    canvas.save();
    canvas.translate(textPoint.dx, textPoint.dy);
    canvas.rotate(textRotation);
    
    double yOffsetChord = degreePainter != null ? -wheelSize * 0.01 : 0;
    
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2 + yOffsetChord));
    
    if (degreePainter != null) {
      double yOffsetDegree = textPainter.height / 2 + yOffsetChord + wheelSize * 0.002;
      degreePainter.paint(canvas, Offset(-degreePainter.width / 2, yOffsetDegree));
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WheelBasePainter oldDelegate) {
    return oldDelegate.usedChords != usedChords || oldDelegate.rotationTurns != rotationTurns;
  }
}

class _WheelMaskPainter extends CustomPainter {
  final ColorScheme colors;
  final bool isMinorKey;

  _WheelMaskPainter({required this.colors, required this.isMinorKey});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final rOuter = radius;
    final rMiddle = radius * 0.72;
    final rInner = radius * 0.44;
    final rHole = radius * 0.22;

    final double sliceAngle = (2 * math.pi) / 12;

    final Path fullCircle = Path()..addOval(Rect.fromCircle(center: center, radius: radius + 2));
    
    Path getCell(double start, double sweep, double rOut, double rIn) {
      final p = Path();
      p.addArc(Rect.fromCircle(center: center, radius: rOut), start, sweep);
      p.arcTo(Rect.fromCircle(center: center, radius: rIn), start + sweep, -sweep, false);
      p.close();
      return p;
    }

    final double startAngleLeft = -math.pi / 2 - (1.5 * sliceAngle);
    final double startAngleCenter = -math.pi / 2 - (0.5 * sliceAngle);
    final double startAngleRight = -math.pi / 2 + (0.5 * sliceAngle);

    final pathSub = getCell(startAngleLeft, sliceAngle, rOuter, rInner);
    final pathTon = getCell(startAngleCenter, sliceAngle, rOuter, rInner);
    final pathDom = getCell(startAngleRight, sliceAngle, rOuter, rInner);
    final pathDimHole = getCell(startAngleCenter, sliceAngle, rInner, rHole);

    final Path wideCutout = Path.combine(PathOperation.union, pathSub, Path.combine(PathOperation.union, pathTon, pathDom));
    final Path finalCutout = Path.combine(PathOperation.union, wideCutout, pathDimHole);
    
    final Path maskPath = Path.combine(PathOperation.difference, fullCircle, finalCutout);

    final paintMask = Paint()
      ..color = colors.surface.withOpacity(0.85) // Dark transparent overlay
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, paintMask);
    
    final strokeWidth = 2.5;
    final green = const Color(0xFF4CAF50);
    final blue = const Color(0xFF2196F3);
    final orange = const Color(0xFFFF9800);

    void drawCell(Path p, Color c) {
      canvas.drawPath(p, Paint()..color=c.withOpacity(0.15)..style=PaintingStyle.fill);
      canvas.drawPath(p, Paint()..color=c..style=PaintingStyle.stroke..strokeWidth=strokeWidth);
    }

    final pathCenterMajor = getCell(startAngleCenter, sliceAngle, rOuter, rMiddle);
    final pathCenterMinor = getCell(startAngleCenter, sliceAngle, rMiddle, rInner);
    final pathCenterDim   = getCell(startAngleCenter, sliceAngle, rInner, rHole);

    final pathLeftMajor   = getCell(startAngleLeft, sliceAngle, rOuter, rMiddle);
    final pathLeftMinor   = getCell(startAngleLeft, sliceAngle, rMiddle, rInner);

    final pathRightMajor  = getCell(startAngleRight, sliceAngle, rOuter, rMiddle);
    final pathRightMinor  = getCell(startAngleRight, sliceAngle, rMiddle, rInner);

    if (isMinorKey) {
      drawCell(pathCenterMajor, blue); // III
      drawCell(pathCenterMinor, blue); // i
      drawCell(pathCenterDim, green);  // ii°
      drawCell(pathLeftMajor, blue);   // VI
      drawCell(pathLeftMinor, green);  // iv
      drawCell(pathRightMajor, orange);// VII
      drawCell(pathRightMinor, orange);// v
    } else {
      drawCell(pathCenterMajor, blue); // I
      drawCell(pathCenterMinor, blue); // vi
      drawCell(pathCenterDim, orange); // vii°
      drawCell(pathLeftMajor, green);  // IV
      drawCell(pathLeftMinor, green);  // ii
      drawCell(pathRightMajor, orange);// V
      drawCell(pathRightMinor, blue);  // iii
    }
  }

  @override
  bool shouldRepaint(covariant _WheelMaskPainter oldDelegate) => false;
}
