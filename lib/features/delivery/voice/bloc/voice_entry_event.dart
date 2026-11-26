part of 'voice_entry_bloc.dart';

sealed class VoiceEntryEvent extends Equatable {
  const VoiceEntryEvent();

  @override
  List<Object?> get props => [];
}

/// Open the microphone. Sent when the sheet opens and on "again".
final class VoiceListenRequested extends VoiceEntryEvent {
  const VoiceListenRequested();
}

final class _VoiceTranscriptReceived extends VoiceEntryEvent {
  const _VoiceTranscriptReceived(this.text, {required this.isFinal});

  final String text;
  final bool isFinal;

  @override
  List<Object?> get props => [text, isFinal];
}

/// The recogniser failed, or the first-word timeout ran out.
final class _VoiceNothingHeard extends VoiceEntryEvent {
  const _VoiceNothingHeard();
}
