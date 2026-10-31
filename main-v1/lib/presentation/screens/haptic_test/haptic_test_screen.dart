import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/braille_cell.dart';
import '../../../domain/entities/haptic_profile_model.dart';
import '../../../domain/entities/haptic_sequence.dart';
import '../../providers/haptic_providers.dart';

/// Developer/calibration screen: type text, tune timings, feel it.
class HapticTestScreen extends ConsumerStatefulWidget {
  const HapticTestScreen({super.key});

  @override
  ConsumerState<HapticTestScreen> createState() => _HapticTestScreenState();
}

class _HapticTestScreenState extends ConsumerState<HapticTestScreen> {
  final _controller = TextEditingController(text: 'hello world');
  final _stopwatch = Stopwatch();
  Timer? _ticker;

  BrailleDocument? _document;
  HapticSequence? _sequence;
  int? _activeIndex;
  String? _error;

  bool get _playing => _ticker != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuildPreview);
    _rebuildPreview();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Re-translates on every edit so the Braille preview and duration are live.
  Future<void> _rebuildPreview() async {
    final document =
        await ref.read(textProcessorProvider).process(_controller.text);
    if (!mounted) return;
    final profile = ref.read(hapticProfileProvider);
    setState(() {
      _document = document;
      _sequence = ref.read(hapticEngineProvider).build(document, profile);
    });
  }

  Future<void> _play() async {
    await _stop();
    await _rebuildPreview();
    final sequence = _sequence;
    if (sequence == null || sequence.isEmpty) return;

    try {
      await ref.read(hapticPlayerProvider).play(sequence);
    } catch (e) {
      setState(() => _error = '$e');
      return;
    }

    _stopwatch
      ..reset()
      ..start();
    setState(() {
      _error = null;
      _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final elapsed = _stopwatch.elapsedMilliseconds;
        if (elapsed >= sequence.totalDurationMs) {
          _finish();
          return;
        }
        final index = sequence.tokenAt(elapsed)?.sourceIndex;
        if (index != _activeIndex) setState(() => _activeIndex = index);
      });
    });
  }

  Future<void> _stop() async {
    if (!_playing) return;
    _finish();
    await ref.read(hapticPlayerProvider).stop();
  }

  void _finish() {
    _ticker?.cancel();
    _stopwatch.stop();
    setState(() {
      _ticker = null;
      _activeIndex = null;
    });
  }

  void _updateProfile(HapticProfileModel profile) {
    ref.read(hapticProfileProvider.notifier).state = profile;
    _rebuildPreview();
  }

  void _customise(HapticProfileModel profile) =>
      _updateProfile(profile.copyWith(id: 'custom', name: 'Custom'));

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(hapticProfileProvider);
    final caps = ref.watch(hapticCapabilitiesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Haptic Test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            caps.when(
              data: (c) => c.hasVibrator
                  ? (c.hasAmplitudeControl
                      ? const SizedBox.shrink()
                      : const _Notice(
                          'This phone cannot vary vibration strength. '
                          'The cell anchor is felt only as a shorter pulse.'))
                  : const _Notice('No vibration motor detected on this device.'),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => _Notice('Could not read haptic capabilities: $e'),
            ),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(
                labelText: 'Text to feel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _Preview(document: _document, activeIndex: _activeIndex),
            const SizedBox(height: 8),
            if (_sequence case final s?)
              Text(
                'Length: ${(s.totalDurationMs / 1000).toStringAsFixed(1)} s'
                '${_document!.unsupportedIndices.isEmpty ? '' : ' · '
                    '${_document!.unsupportedIndices.length} unsupported characters skipped'}',
                style: theme.textTheme.bodyLarge,
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                onPressed: _playing ? _stop : _play,
                icon: Icon(_playing ? Icons.stop : Icons.vibration, size: 32),
                label: Text(
                  _playing ? 'Stop' : 'Play',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            if (_error != null) _Notice(_error!),
            const SizedBox(height: 24),
            Text('Speed preset', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              segments: [
                for (final p in HapticProfileModel.presets)
                  ButtonSegment(value: p.id, label: Text(p.name)),
              ],
              selected: {profile.id},
              onSelectionChanged: (ids) {
                if (ids.isEmpty) return;
                _updateProfile(HapticProfileModel.presets
                    .firstWhere((p) => p.id == ids.first));
              },
            ),
            const SizedBox(height: 16),
            for (final param in HapticTimingParam.values)
              _TimingSlider(
                param: param,
                value: profile.valueOf(param),
                onChanged: (v) => _customise(profile.withTiming(param, v)),
              ),
            _UnitSlider(
              label: 'Dot strength',
              value: profile.intensity,
              onChanged: (v) => _customise(profile.copyWith(intensity: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cell start tick'),
              subtitle: const Text('A soft tick before every letter'),
              value: profile.cellAnchorEnabled,
              onChanged: (v) => _customise(profile.copyWith(cellAnchorEnabled: v)),
            ),
            if (profile.cellAnchorEnabled)
              _UnitSlider(
                label: 'Start tick strength',
                value: profile.anchorIntensity,
                onChanged: (v) =>
                    _customise(profile.copyWith(anchorIntensity: v)),
              ),
            for (final issue in profile.validate()) _Notice(issue.message),
          ],
        ),
      ),
    );
  }
}

/// Source text with the currently-felt character highlighted, plus its cells.
class _Preview extends StatelessWidget {
  const _Preview({required this.document, required this.activeIndex});

  final BrailleDocument? document;
  final int? activeIndex;

  @override
  Widget build(BuildContext context) {
    final doc = document;
    if (doc == null || doc.tokens.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: Wrap(
        spacing: 4,
        runSpacing: 8,
        children: [
          for (final token in doc.tokens)
            if (token.isWordBreak)
              const SizedBox(width: 16)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: token.sourceIndex == activeIndex
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      token.cells.map((c) => c.unicode).join(),
                      style: TextStyle(
                        fontSize: 28,
                        color: token.sourceIndex == activeIndex
                            ? scheme.onPrimary
                            : scheme.onSurface,
                      ),
                    ),
                    Text(
                      token.source,
                      style: TextStyle(
                        fontSize: 16,
                        color: token.sourceIndex == activeIndex
                            ? scheme.onPrimary
                            : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TimingSlider extends StatelessWidget {
  const _TimingSlider({
    required this.param,
    required this.value,
    required this.onChanged,
  });

  final HapticTimingParam param;
  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = param.maxMs > 1000 ? 50 : 5;
    final ms = value.inMilliseconds.clamp(param.minMs, param.maxMs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${param.label}: $ms ms',
            style: Theme.of(context).textTheme.bodyLarge),
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
    );
  }
}

class _UnitSlider extends StatelessWidget {
  const _UnitSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $percent%', style: Theme.of(context).textTheme.bodyLarge),
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

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.error, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message, style: TextStyle(color: scheme.onSurface, fontSize: 16)),
      ),
    );
  }
}
