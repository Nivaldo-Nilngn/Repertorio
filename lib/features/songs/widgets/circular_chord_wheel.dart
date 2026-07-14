import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/harmonic_field_calculator.dart';

class CircularChordWheel extends StatelessWidget {
  final String currentKey;
  final Set<String> usedChords;

  const CircularChordWheel({
    super.key,
    required this.currentKey,
    required this.usedChords,
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keyIndex = _getKeyIndex();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final wheelSize = size * 0.9;
        
        return SizedBox(
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
                  painter: _WheelMaskPainter(colors: colors),
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
              )
            ],
          ),
        );
      },
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

  _WheelBasePainter({
    required this.colors,
    required this.usedChords,
    required this.majorKeys,
    required this.minorKeys,
    required this.dimKeys,
    required this.rotationTurns,
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

      // Draw text for this slice
      final textAngle = -math.pi / 2 + (i * sliceAngle) + globalRotation;
      
      _drawChordText(canvas, center, textAngle, majorKeys[i], (rOuter + rMiddle) / 2, size.width);
      _drawChordText(canvas, center, textAngle, minorKeys[i], (rMiddle + rInner) / 2, size.width);
      _drawChordText(canvas, center, textAngle, dimKeys[i], (rInner + rHole) / 2, size.width);
    }
  }

  void _drawChordText(Canvas canvas, Offset center, double angle, String chord, double radius, double wheelSize) {
    final root = HarmonicFieldCalculator.extractRootChord(chord);
    final isUsed = usedChords.contains(root) || usedChords.contains(chord);
    
    final textPoint = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    // If text is on the bottom half, rotate it so it's readable
    double textRotation = angle + math.pi / 2;
    if (textRotation > math.pi / 2 && textRotation < 3 * math.pi / 2) {
      textRotation += math.pi;
    }

    final textSpan = TextSpan(
      text: chord,
      style: TextStyle(
        color: isUsed ? colors.primary : colors.onSurfaceVariant.withOpacity(0.6),
        fontSize: wheelSize * 0.035,
        fontWeight: isUsed ? FontWeight.bold : FontWeight.w500,
        shadows: isUsed ? [
          Shadow(color: colors.primary.withOpacity(0.6), blurRadius: 8)
        ] : null,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    canvas.save();
    canvas.translate(textPoint.dx, textPoint.dy);
    canvas.rotate(textRotation);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WheelBasePainter oldDelegate) {
    return oldDelegate.usedChords != usedChords || oldDelegate.rotationTurns != rotationTurns;
  }
}

class _WheelMaskPainter extends CustomPainter {
  final ColorScheme colors;

  _WheelMaskPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final rOuter = radius;
    final rMiddle = radius * 0.72;
    final rInner = radius * 0.44;
    final rHole = radius * 0.22;

    final double sliceAngle = (2 * math.pi) / 12;

    // The mask covers the whole circle EXCEPT the active key window.
    // Window: 
    // Outer & Middle rings: covers 3 slices (-1.5 to +1.5 slices from top)
    // Inner ring: covers 1 slice (-0.5 to +0.5 slices from top)
    // Always centered at the top (-pi/2)
    
    final Path fullCircle = Path()..addOval(Rect.fromCircle(center: center, radius: radius + 2));
    
    // Create the cutout path
    final Path cutout = Path();
    
    // Exact top is -pi/2
    final double startAngleWide = -math.pi / 2 - (1.5 * sliceAngle);
    final double sweepAngleWide = 3 * sliceAngle;
    
    final double startAngleNarrow = -math.pi / 2 - (0.5 * sliceAngle);
    final double sweepAngleNarrow = sliceAngle;

    // Wide cutout (Outer and Middle)
    cutout.addArc(Rect.fromCircle(center: center, radius: rOuter), startAngleWide, sweepAngleWide);
    cutout.arcTo(Rect.fromCircle(center: center, radius: rInner), startAngleWide + sweepAngleWide, -sweepAngleWide, false);
    cutout.close();
    
    // Narrow cutout (Inner)
    final Path narrowCutout = Path();
    narrowCutout.addArc(Rect.fromCircle(center: center, radius: rInner), startAngleNarrow, sweepAngleNarrow);
    narrowCutout.arcTo(Rect.fromCircle(center: center, radius: rHole), startAngleNarrow + sweepAngleNarrow, -sweepAngleNarrow, false);
    narrowCutout.close();

    final Path finalCutout = Path.combine(PathOperation.union, cutout, narrowCutout);
    
    // The actual mask to paint is fullCircle MINUS finalCutout
    final Path maskPath = Path.combine(PathOperation.difference, fullCircle, finalCutout);

    final paintMask = Paint()
      ..color = colors.surface.withOpacity(0.85) // Dark transparent overlay
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, paintMask);
    
    // Draw an accent border around the cutout
    final paintAccent = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
      
    canvas.drawPath(finalCutout, paintAccent);
  }

  @override
  bool shouldRepaint(covariant _WheelMaskPainter oldDelegate) => false;
}
