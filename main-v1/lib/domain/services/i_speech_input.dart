/// Speech-to-text, used for spoken training answers and for hearing people
/// to speak a message that is then vibrated.
abstract interface class ISpeechInput {
  /// Asks for microphone permission on first use. False if unavailable.
  Future<bool> initialize();

  bool get isListening;

  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function() onDone,
    bool dictation = false,
  });

  Future<void> stop();
}
