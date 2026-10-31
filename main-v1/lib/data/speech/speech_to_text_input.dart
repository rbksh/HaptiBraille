import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/services/i_speech_input.dart';

/// [ISpeechInput] backed by the OS recogniser (Android SpeechRecognizer).
class SpeechToTextInput implements ISpeechInput {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  void Function()? _onDone;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize() async {
    if (_available) return true;
    _available = await _speech.initialize(
      onStatus: (status) {
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          final done = _onDone;
          _onDone = null;
          done?.call();
        }
      },
      onError: (_) {
        final done = _onDone;
        _onDone = null;
        done?.call();
      },
    );
    return _available;
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function() onDone,
    bool dictation = false,
  }) async {
    if (!await initialize()) {
      onDone();
      return;
    }
    _onDone = onDone;
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: dictation ? ListenMode.dictation : ListenMode.confirmation,
        listenFor: Duration(seconds: dictation ? 60 : 8),
        pauseFor: Duration(seconds: dictation ? 4 : 2),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}
