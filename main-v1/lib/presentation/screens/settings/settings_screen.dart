import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../domain/entities/haptic_profile_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/haptic_providers.dart';
import '../../providers/playback_controller.dart';

/// Haptic timing controls (the anti-"sensory blur" knobs).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final PlaybackController _playback;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackProvider.notifier);
  }

  @override
  void dispose() {
    _playback.stop();
    super.dispose();
  }

  void _set(HapticProfileModel p) => ref.read(hapticProfileProvider.notifier).set(p);

  void _customise(HapticProfileModel p) => _set(p.copyWith(id: 'custom', name: 'Custom'));

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Delete all progress?'),
        content: const Text('This removes every training answer, streak and chart. It cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(attemptsProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(hapticProfileProvider);
    final caps = ref.watch(hapticCapabilitiesProvider);
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            caps.maybeWhen(
              data: (c) => !c.hasVibrator
                  ? const NoticeBox('No vibration motor was detected on this device.')
                  : !c.hasAmplitudeControl
                      ? const NoticeBox(
                          'This phone cannot vary vibration strength, so the strength sliders have no effect.',
                          color: AppColors.talk,
                        )
                      : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
            Text('Reading speed', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('Start slow. Speed up once letters feel clear.',
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(0, 52),
                selectedBackgroundColor: AppColors.accent,
                selectedForegroundColor: AppColors.onAccent,
                textStyle: text.labelLarge,
              ),
              segments: [
                for (final p in HapticProfileModel.presets)
                  ButtonSegment(value: p.id, label: Text(p.name)),
              ],
              selected: {profile.id},
              onSelectionChanged: (ids) {
                if (ids.isEmpty) return;
                _set(HapticProfileModel.presets.firstWhere((p) => p.id == ids.first));
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: OutlinedButton.icon(
                onPressed: playing ? _playback.stop : () => _playback.playText('abc'),
                icon: Icon(playing ? Icons.stop_rounded : Icons.vibration),
                label: Text(playing ? 'Stop' : 'Feel a sample (a b c)'),
              ),
            ),
            for (final issue in profile.validate())
              NoticeBox(
                issue.message,
                color: issue.severity == ProfileIssueSeverity.error ? AppColors.error : AppColors.accent,
              ),
            const SectionTitle('Timing'),
            for (final param in HapticTimingParam.values)
              _TimingSlider(
                param: param,
                value: profile.valueOf(param),
                onChanged: (v) => _customise(profile.withTiming(param, v)),
              ),
            const SectionTitle('Feel'),
            _UnitSlider(
              label: 'Dot strength',
              value: profile.intensity,
              onChanged: (v) => _customise(profile.copyWith(intensity: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Start-of-letter tick', style: text.bodyLarge),
              subtitle: Text('A soft tick before every letter, so you know where it begins.',
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
              value: profile.cellAnchorEnabled,
              onChanged: (v) => _customise(profile.copyWith(cellAnchorEnabled: v)),
            ),
            if (profile.cellAnchorEnabled)
              _UnitSlider(
                label: 'Tick strength',
                value: profile.anchorIntensity,
                onChanged: (v) => _customise(profile.copyWith(anchorIntensity: v)),
              ),
            const SectionTitle('Data'),
            OutlinedButton.icon(
              onPressed: _confirmClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.5),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete all progress'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingSlider extends StatelessWidget {
  const _TimingSlider({required this.param, required this.value, required this.onChanged});

  final HapticTimingParam param;
  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = param.maxMs > 1000 ? 50 : 5;
    final ms = value.inMilliseconds.clamp(param.minMs, param.maxMs);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(param.label, style: text.bodyLarge)),
              Text('$ms ms', style: text.titleMedium?.copyWith(color: AppColors.accent)),
            ],
          ),
          Slider(
            min: param.minMs.toDouble(),
            max: param.maxMs.toDouble(),
            divisions: (param.maxMs - param.minMs) ~/ step,
            value: ms.toDouble(),
            label: '$ms ms',
            semanticFormatterCallback: (v) => '${v.round()} milliseconds',
            onChanged: (v) => onChanged(Duration(milliseconds: v.round())),
          ),
        ],
      ),
    );
  }
}

class _UnitSlider extends StatelessWidget {
  const _UnitSlider({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: text.bodyLarge)),
            Text('$percent%', style: text.titleMedium?.copyWith(color: AppColors.accent)),
          ],
        ),
        Slider(
          min: 0.1,
          max: 1.0,
          divisions: 18,
          value: value.clamp(0.1, 1.0),
          label: '$percent%',
          semanticFormatterCallback: (v) => '${(v * 100).round()} percent',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
