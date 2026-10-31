import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/braille_cell_view.dart';
import '../../core/widgets/common.dart';
import '../providers/playback_controller.dart';

/// Big animated cell + the text being felt, with the current character
/// highlighted. Shared by the Read and Talk screens.
class LivePlaybackPanel extends ConsumerWidget {
  const LivePlaybackPanel({super.key, this.placeholder = 'Press Play to feel your text.'});

  final String placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final text = Theme.of(context).textTheme;
    final doc = playback.document;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outline, width: 1.5),
      ),
      child: Column(
        children: [
          BrailleCellView(
            cell: playback.frame.cell,
            activeSlot: playback.frame.activeSlot,
            anchorActive: playback.frame.anchorActive,
            dotSize: 30,
          ),
          const SizedBox(height: 20),
          if (doc == null || doc.text.trim().isEmpty)
            Text(placeholder,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: AppColors.textSecondary))
          else
            ExcludeSemantics(
              child: Text.rich(
                TextSpan(children: _highlighted(doc.text, playback.activeSourceIndex)),
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w400),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: playback.progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.accent,
              semanticsLabel: 'Playback progress',
            ),
          ),
          if (playback.hapticsUnavailable)
            const NoticeBox(
              'This device cannot vibrate, so only the animation is shown.',
              color: AppColors.talk,
            ),
        ],
      ),
    );
  }

  List<TextSpan> _highlighted(String text, int? index) {
    if (index == null || index < 0 || index >= text.length) {
      return [TextSpan(text: text)];
    }
    return [
      TextSpan(text: text.substring(0, index), style: const TextStyle(color: AppColors.textMuted)),
      TextSpan(
        text: text[index],
        style: const TextStyle(
          color: AppColors.onAccent,
          backgroundColor: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
      TextSpan(text: text.substring(index + 1)),
    ];
  }
}
