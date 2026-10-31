import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../domain/services/i_speech_input.dart';
import '../../providers/app_providers.dart';
import '../../providers/playback_controller.dart';
import '../../widgets/live_playback_panel.dart';

/// Text ingestion: type, paste, dictate or receive a (demo) notification,
/// then feel it.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _controller = TextEditingController(text: 'hello world');
  bool _listening = false;
  String? _notice;
  int _demoIndex = 0;

  static const _demoNotifications = [
    'Mum: Dinner at 7?',
    'Bus 42 arrives in 3 minutes.',
    'Bank: Your code is 4821.',
    'Sam: Running late, see you soon!',
  ];

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
    _controller.dispose();
    super.dispose();
  }

  void _play() => _playback.playText(_controller.text);

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text?.trim();
    if (pasted == null || pasted.isEmpty) {
      setState(() => _notice = 'The clipboard is empty.');
      return;
    }
    setState(() {
      _notice = null;
      _controller.text = pasted;
    });
  }

  Future<void> _toggleDictation() async {
    final speech = _speech;
    if (_listening) {
      await speech.stop();
      return;
    }
    if (!await speech.initialize()) {
      setState(() => _notice = 'Speech recognition is unavailable. Check microphone permission.');
      return;
    }
    setState(() {
      _listening = true;
      _notice = null;
    });
    await speech.listen(
      dictation: true,
      onResult: (words, _) {
        if (mounted) setState(() => _controller.text = words);
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  /// Mock notification hook – a real NotificationListenerService comes later.
  void _demoNotification() {
    final message = _demoNotifications[_demoIndex++ % _demoNotifications.length];
    setState(() => _controller.text = message);
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(playbackProvider.select((s) => s.playing));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Read')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const LivePlaybackPanel(),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 6,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w400),
              decoration: const InputDecoration(
                labelText: 'Text to feel',
                hintText: 'Type, paste or dictate…',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste'),
                ),
                OutlinedButton.icon(
                  onPressed: _toggleDictation,
                  style: _listening
                      ? OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error, width: 2),
                          foregroundColor: AppColors.error,
                        )
                      : null,
                  icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
                  label: Text(_listening ? 'Stop listening' : 'Dictate'),
                ),
                OutlinedButton.icon(
                  onPressed: _demoNotification,
                  icon: const Icon(Icons.notifications_none),
                  label: const Text('Demo notification'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _controller.clear()),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
            if (_notice != null) NoticeBox(_notice!),
            const SizedBox(height: 20),
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                onPressed: playing ? _playback.stop : _play,
                icon: Icon(playing ? Icons.stop_rounded : Icons.vibration, size: 30),
                label: Text(playing ? 'Stop' : 'Play', style: const TextStyle(fontSize: 22)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
