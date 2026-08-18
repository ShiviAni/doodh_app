import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper over the platform speech recogniser.
///
/// Kept behind a small interface so the entry sheet can be tested without a
/// microphone, and so a device with no recogniser degrades to the ordinary
/// tap-and-step flow instead of presenting a dead button.
abstract class SpeechService {
  Future<bool> initialise();

  /// True once [initialise] has confirmed a working recogniser.
  bool get isAvailable;

  bool get isListening;

  /// [onResult] fires repeatedly with partial text, then a final result.
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
    String localeId,
  });

  Future<void> stop();
  Future<void> cancel();
}

class DeviceSpeechService implements SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialise() async {
    try {
      _available = await _speech.initialize(
        onError: (e) => debugPrint('speech error: ${e.errorMsg}'),
        onStatus: (s) => debugPrint('speech status: $s'),
      );
    } catch (e) {
      debugPrint('speech unavailable: $e');
      _available = false;
    }
    return _available;
  }

  @override
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
    String localeId = 'hi_IN',
  }) async {
    if (!_available) return;
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        // Partial results let the sheet show words as they are spoken, which
        // is the only feedback that the microphone is actually hearing him.
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        // Generous, because a house name plus a quantity is spoken slowly and
        // often after a pause.
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
