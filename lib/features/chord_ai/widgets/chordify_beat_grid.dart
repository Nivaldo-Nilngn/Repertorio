import 'package:flutter/material.dart';
import '../services/setlist_repository.dart';
import '../services/chord_simplifier.dart';

class ChordifyBeatGrid extends StatefulWidget {
  final List<MeasureBeat> measures;
  final double currentSeconds;
  final int transposeSemitones;
  final ChordComplexity complexity;
  final Function(double seekSeconds) onSeek;

  const ChordifyBeatGrid({
    super.key,
    required this.measures,
    required this.currentSeconds,
    required this.transposeSemitones,
    this.complexity = ChordComplexity.advanced,
    required this.onSeek,
  });

  @override
  State<ChordifyBeatGrid> createState() => _ChordifyBeatGridState();
}

class _ChordifyBeatGridState extends State<ChordifyBeatGrid> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void didUpdateWidget(covariant ChordifyBeatGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAutoScroll();
  }

  void _checkAutoScroll() {
    final activeIdx = _getActiveMeasureIndex();
    if (activeIdx != -1 && activeIdx != _lastActiveIndex) {
      _lastActiveIndex = activeIdx;
      // Rolagem suave para manter o compasso ativo centralizado
      if (_scrollController.hasClients) {
        final targetOffset = (activeIdx * 105.0) - 160.0;
        final clamped = targetOffset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  int _getActiveMeasureIndex() {
    for (int i = 0; i < widget.measures.length; i++) {
      final m = widget.measures[i];
      if (widget.currentSeconds >= m.startSeconds &&
          widget.currentSeconds < m.startSeconds + m.durationSeconds) {
        return i;
      }
    }
    return -1;
  }

  /// Calcula a duração total contínua e a quantidade de compassos que o mesmo acorde dura
  (int, double) _getChordSpan(int startIndex) {
    if (startIndex < 0 || startIndex >= widget.measures.length) return (1, 0.0);
    final baseChord = widget.measures[startIndex].chord;
    int count = 0;
    double totalDur = 0.0;
    for (int i = startIndex; i < widget.measures.length; i++) {
      if (widget.measures[i].chord == baseChord) {
        count++;
        totalDur += widget.measures[i].durationSeconds;
      } else {
        break;
      }
    }
    return (count, totalDur);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.measures.isEmpty) {
      return const SizedBox(height: 80);
    }

    final activeIndex = _getActiveMeasureIndex();

    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1222),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: widget.measures.length,
        itemBuilder: (context, index) {
          final measure = widget.measures[index];
          final isActive = index == activeIndex;

          // Compressão Harmônica (estilo Chorda):
          // Verifica se este compasso é o início de um novo acorde ou continuação da mesma nota
          final isFirstOfChord =
              index == 0 || widget.measures[index - 1].chord != measure.chord;
          final isSameChordContinuation = !isFirstOfChord;

          // Se for o primeiro do acorde, calcula quantos compassos ele dura e o tempo total
          final (spanCount, spanDuration) = isFirstOfChord
              ? _getChordSpan(index)
              : (1, measure.durationSeconds);

          // Progresso linear contínuo (0.0 a 1.0) dentro do compasso ativo
          double linearProgress = 0.0;
          int activeBeat = 0;
          if (isActive) {
            linearProgress = ((widget.currentSeconds - measure.startSeconds) /
                    measure.durationSeconds)
                .clamp(0.0, 1.0);
            activeBeat = (linearProgress * 4).clamp(0, 3).toInt();
          }

          final transposed = SetlistRepository.transposeChord(
            measure.chord,
            widget.transposeSemitones,
          );
          final displayChord =
              ChordSimplifier.simplify(transposed, widget.complexity);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => widget.onSeek(measure.startSeconds),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 92,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1E284A)
                      : (isSameChordContinuation
                          ? const Color(0xFF131728)
                          : const Color(0xFF171D33)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF2F6BFF)
                        : (isFirstOfChord
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.06)),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2F6BFF).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    // Preenchimento linear contínuo do tempo ativo (estilo DAW / Chorda)
                    if (isActive)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 92 * linearProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.horizontal(
                              left: const Radius.circular(8),
                              right: linearProgress >= 0.96
                                  ? const Radius.circular(8)
                                  : Radius.zero,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2F6BFF).withValues(alpha: 0.25),
                                const Color(0xFF00E5FF).withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Conteúdo do compasso
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Topo: Número do compasso e duração/tempo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${measure.measureNumber}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? const Color(0xFF00E5FF)
                                      : Colors.white38,
                                ),
                              ),
                              if (isFirstOfChord && spanCount > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2F6BFF)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${spanCount}x',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00E5FF),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  _formatTime(measure.startSeconds),
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                            ],
                          ),

                          // Acorde central:
                          // Se for o início do bloco harmônico -> exibe a nota em destaque.
                          // Se for repetição consecutiva -> mostra linha contínua sutil sem poluir!
                          Expanded(
                            child: Center(
                              child: isFirstOfChord
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        displayChord,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.9),
                                          shadows: isActive
                                              ? [
                                                  const Shadow(
                                                    color: Color(0xFF00E5FF),
                                                    blurRadius: 8,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 28,
                                      height: 2.5,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFF00E5FF)
                                            : Colors.white
                                                .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                            ),
                          ),

                          // Base: 4 batidas discretas em tempo linear
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(4, (beatIdx) {
                              final isCurrentBeat =
                                  isActive && activeBeat == beatIdx;
                              return Container(
                                width: 16,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: isCurrentBeat
                                      ? const Color(0xFF00E5FF)
                                      : (isActive
                                          ? const Color(0xFF2F6BFF)
                                              .withValues(alpha: 0.4)
                                          : Colors.white
                                              .withValues(alpha: 0.1)),
                                  boxShadow: isCurrentBeat
                                      ? [
                                          const BoxShadow(
                                            color: Color(0xFF00E5FF),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(double sec) {
    final s = sec.toInt();
    final m = (s ~/ 60).toString();
    final remSec = (s % 60).toString().padLeft(2, '0');
    return '$m:$remSec';
  }
}
