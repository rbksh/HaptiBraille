import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../domain/services/i_speech_input.dart';
import '../../providers/app_providers.dart';
import '../../providers/playback_controller.dart';
import '../../widgets/live_playback_panel.dart';

/// Conversation mode: a hearing person speaks, the message is vibrated.
class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key});

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  bool _listening = false;
  bool _autoVibrate = true;
  String _transcript = '';
  String? _notice;
  final List<String> _history = [];

  late final PlaybackController _playback;
  late final ISpeechInput _speech;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackProvider.notifier);
    _speech = ref.read(speechInputProvider);
  }

  @override
  void dispose() {
    _playback.stop();
    if (_listening) _speech.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    final speech = _speech;
    if (_listening) {
      await speech.stop();
      return;
    }
    await _playback.stop();
    if (!await speech.initialize()) {
      setState(() => _notice =
          'Speech recognition is unavailable. Allow microphone access in system settings.');
      return;
    }
    setState(() {
      _listening = true;
      _transcript = '';
      _notice = null;
    });
    var delivered = false;
    void deliver() {
      final message = _transcript.trim();
      if (delivered || message.isEmpty) return;
      delivered = true;
      setState(() => _history.insert(0, message));
      if (_autoVibrate) _playback.playText(message);
    }

    await speech.listen(
      dictation: true,
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = words);
        if (isFinal) deliver();
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _listening = false);
        deliver();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final playing = ref.watch(playbackProvider.select((s) => s.playing));

    return Scaffold(
      appBar: AppBar(title: const Text('Talk to me')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Hand the phone to the person you are with.',
              style: text.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'They tap the microphone and speak. When they stop, '
              'their words are sent to you as Braille vibrations.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            Center(child: _MicButton(listening: _listening, onTap: _toggle)),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _listening
                    ? (_transcript.isEmpty ? 'Listening…' : _transcript)
                    : (_transcript.isEmpty ? 'Tap the microphone to speak' : _transcript),
                textAlign: TextAlign.center,
                style: _transcript.isEmpty
                    ? text.bodyLarge?.copyWith(color: AppColors.textSecondary)
                    : text.headlineSmall,
              ),
            ),
            if (_notice != null) NoticeBox(_notice!),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibrate as soon as they finish'),
              value: _autoVibrate,
              onChanged: (v) => setState(() => _autoVibrate = v),
            ),
            const SizedBox(height: 12),
            const LivePlaybackPanel(placeholder: 'The message will appear here as it is felt.'),
            if (_history.isNotEmpty) ...[
              const SectionTitle('Messages'),
              for (final message in _history)
                Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.outline),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    title: Text(message, style: text.bodyLarge),
                    trailing: IconButton(
                      tooltip: 'Feel again',
                      iconSize: 30,
                      icon: Icon(playing ? Icons.stop_rounded : Icons.vibration,
                          color: AppColors.accent),
                      onPressed: () =>
                          playing ? _playback.stop() : _playback.playText(message),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didUpdateWidget(covariant _MicButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !reduceMotion(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.listening ? AppColors.error : AppColors.talk;
    return Semantics(
      button: true,
      label: widget.listening ? 'Stop listening' : 'Start listening',
      excludeSemantics: true,
      child: SizedBox(
        width: 200,
        height: 200,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            children: [
              if (widget.listening)
                Container(
                  width: 140 + 60 * _pulse.value,
                  height: 140 + 60 * _pulse.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.25 * (1 - _pulse.value)),
                  ),
                ),
              child!,
            ],
          ),
          child: Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              child: SizedBox(
                width: 140,
                height: 140,
                child: Icon(
                  widget.listening ? Icons.stop_rounded : Icons.mic,
                  size: 64,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
