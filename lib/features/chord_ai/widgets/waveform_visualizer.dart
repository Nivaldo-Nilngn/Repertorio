import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class WaveformVisualizerWidget extends StatelessWidget {
  final double rms;
  final Float64List chromagram;
  final bool isListening;

  const WaveformVisualizerWidget({
    super.key,
    required this.rms,
    required this.chromagram,
    required this.isListening,
  });

  static const List<String> pitchNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ESPECTRO HARMÔNICO (CROMAGRAMA)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isListening ? const Color(0xFF00E676) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isListening ? 'SINAL ATIVO' : 'PAUSADO',
                    style: TextStyle(
                      color: isListening ? const Color(0xFF00E676) : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 12 barras de cromagrama para cada nota musical
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (index) {
                final double energy = chromagram.length > index ? chromagram[index] : 0.0;
                final double barHeight = max(4.0, energy * 50.0);
                final bool isPeak = energy > 0.45;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 14,
                      height: barHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isPeak
                              ? [const Color(0xFF00E5FF), const Color(0xFFE040FB)]
                              : [const Color(0xFF1E88E5).withOpacity(0.4), const Color(0xFF00E5FF).withOpacity(0.6)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isPeak
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, -2),
                                ),
                              ]
                            : [],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pitchNames[index],
                      style: TextStyle(
                        color: isPeak ? Colors.white : Colors.white.withOpacity(0.35),
                        fontSize: 9,
                        fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
