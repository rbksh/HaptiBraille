import 'package:flutter/material.dart';

import '../../domain/entities/braille_cell.dart';
import '../motion.dart';
import '../theme/app_theme.dart';

/// Visual 6-dot cell, synchronised with vibration playback.
///
///     1 ● ● 4
///     2 ● ● 5
///     3 ● ● 6
///
/// Raised dots are filled; the dot being vibrated right now grows and glows;
/// the cell border flashes when the start-of-cell tick plays.
class BrailleCellView extends StatelessWidget {
  const BrailleCellView({
    super.key,
    this.cell,
    this.activeSlot,
    this.anchorActive = false,
    this.dotSize = 34,
    this.showNumbers = false,
    this.dimmed = false,
  });

  final BrailleCell? cell;
  final int? activeSlot;
  final bool anchorActive;
  final double dotSize;
  final bool showNumbers;

  /// Hide which dots are raised (training quiz) but keep the motion.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final gap = dotSize * 0.55;
    final d = motion(context, const Duration(milliseconds: 140));

    Widget dot(int slot) {
      final raised = !dimmed && (cell?.isRaisedAt(slot) ?? false);
      final active = activeSlot == slot;
      final fill = active
          ? AppColors.accent
          : raised
              ? AppColors.accent.withValues(alpha: 0.85)
              : Colors.transparent;
      return SizedBox(
        width: dotSize * 1.35,
        height: dotSize * 1.35,
        child: Center(
          child: AnimatedContainer(
            duration: d,
            curve: Curves.easeOutCubic, // no overshoot: shadows can't lerp below zero
            width: active ? dotSize * 1.3 : dotSize,
            height: active ? dotSize * 1.3 : dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: raised || active ? AppColors.accent : AppColors.outline,
                width: 2.5,
              ),
              boxShadow: active
                  ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.55), blurRadius: dotSize * 0.8, spreadRadius: 2)]
                  : null,
            ),
            alignment: Alignment.center,
            child: showNumbers
                ? Text(
                    '${slot + 1}',
                    style: TextStyle(
                      fontSize: dotSize * 0.45,
                      fontWeight: FontWeight.w700,
                      color: raised || active ? AppColors.onAccent : AppColors.textMuted,
                    ),
                  )
                : null,
          ),
        ),
      );
    }

    return Semantics(
      label: _semanticLabel(),
      child: AnimatedContainer(
        duration: d,
        padding: EdgeInsets.symmetric(horizontal: gap, vertical: gap * 0.8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(dotSize * 0.9),
          border: Border.all(
            color: anchorActive ? AppColors.accent : AppColors.outline,
            width: anchorActive ? 3 : 1.5,
          ),
          boxShadow: anchorActive
              ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 24)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(mainAxisSize: MainAxisSize.min, children: [dot(0), dot(1), dot(2)]),
            SizedBox(width: gap * 0.6),
            Column(mainAxisSize: MainAxisSize.min, children: [dot(3), dot(4), dot(5)]),
          ],
        ),
      ),
    );
  }

  String _semanticLabel() {
    if (dimmed || cell == null) return 'Braille cell';
    final dots = cell!.raisedDots;
    return dots.isEmpty ? 'Empty Braille cell' : 'Braille cell, dots ${dots.join(', ')}';
  }
}

/// Six large buttons in cell layout – the answer pad for Level 1.
class DotPicker extends StatelessWidget {
  const DotPicker({super.key, required this.onSelected, this.selected, this.correct});

  final ValueChanged<int> onSelected;

  /// After answering: the learner's pick and the right answer, for colouring.
  final int? selected;
  final int? correct;

  static const _positions = ['top left', 'middle left', 'bottom left', 'top right', 'middle right', 'bottom right'];

  @override
  Widget build(BuildContext context) {
    Widget button(int dot) {
      final answered = correct != null;
      final isCorrect = answered && dot == correct;
      final isWrongPick = answered && dot == selected && dot != correct;
      final color = isCorrect
          ? AppColors.success
          : isWrongPick
              ? AppColors.error
              : AppColors.surfaceHigh;
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Semantics(
          button: true,
          label: 'Dot $dot, ${_positions[dot - 1]}',
          excludeSemantics: true,
          child: Material(
            color: color,
            shape: const CircleBorder(side: BorderSide(color: AppColors.outline, width: 2)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: answered ? null : () => onSelected(dot),
              child: SizedBox(
                width: 84,
                height: 84,
                child: Center(
                  child: Text(
                    '$dot',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: isCorrect || isWrongPick ? AppColors.onAccent : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(children: [button(1), button(2), button(3)]),
        const SizedBox(width: 24),
        Column(children: [button(4), button(5), button(6)]),
      ],
    );
  }
}
