import 'package:doodh_app/features/delivery/voice/speech_service.dart';

/// Scriptable stand-in for the platform recogniser.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.available = true, this.transcript, this.error});

  final bool available;

  /// Delivered as a final result when listening starts. Null means the
  /// recogniser never answers — the case a real device with no speech service
  /// produces.
  final String? transcript;
  final String? error;

  bool listenCalled = false;
  String? lastLocale;

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => false;

  @override
  Future<bool> initialise() async => available;

  @override
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(String message)? onError,
    String localeId = 'hi_IN',
  }) async {
    listenCalled = true;
    lastLocale = localeId;
    if (error != null) {
      onError?.call(error!);
      return;
    }
    if (transcript != null) onResult(transcript!, true);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}
