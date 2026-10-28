import 'package:flutter/material.dart';
import '../models/chord_data.dart';

class ChordTimelineWidget extends StatelessWidget {
  final List<DetectedChordEvent> history;
  final String activeChord;
  final ValueChanged<String>? onChordSelected;

  const ChordTimelineWidget({
    super.key,
    required this.history,
    required this.activeChord,
    this.onChordSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty && activeChord == '...') {
      return Container(
        height: 70,
        alignment: Alignment.center,
        child: Text(
          'Toque ou cante para gerar a linha do tempo de acordes',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return SizedBox(
      height: 74,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true, // Mostra os acordes mais recentes primeiro
        itemCount: history.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // O acorde mais recente / atual em destaque
            return _buildChordBubble(
              chord: activeChord,
              isActive: true,
              confidence: 1.0,
            );
          }

          final event = history[history.length - index];
          return _buildChordBubble(
            chord: event.chordName,
            isActive: false,
            confidence: event.confidence,
          );
        },
      ),
    );
  }

  Widget _buildChordBubble({
    required String chord,
    required bool isActive,
    required double confidence,
  }) {
    final Color primaryColor = isActive ? const Color(0xFF00E5FF) : const Color(0xFF2C3246);
    final Color textColor = isActive ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () {
        if (onChordSelected != null && chord != '...') {
          onChordSelected!(chord);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : primaryColor.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.12),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            chord,
            style: TextStyle(
              color: textColor,
              fontSize: isActive ? 20 : 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
