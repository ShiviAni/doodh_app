part of 'voice_entry_bloc.dart';

enum VoicePhase {
  /// Checking the recogniser before the microphone opens.
  starting,
  listening,

  /// A final result came back.
  heard,

  /// The recogniser errored, or nothing arrived before the timeout. Silence
  /// and a missing recogniser look identical from here, so both end in the
  /// same advice.
  heardNothing,

  /// No recogniser on this device at all.
  unavailable,
}

final class VoiceEntryState extends Equatable {
  const VoiceEntryState({
    this.phase = VoicePhase.starting,
    this.transcript = '',
    this.entry,
  });

  final VoicePhase phase;
  final String transcript;
  final VoiceEntry? entry;

  bool get isListening =>
      phase == VoicePhase.listening || phase == VoicePhase.starting;

  /// Save stays disabled until a house *and* a quantity are both understood,
  /// never a half-guessed save.
  bool get canConfirm => entry?.isUsable ?? false;

  /// What to hand back to the caller when he confirms. Null until usable.
  VoiceResult? get result {
    final e = entry;
    if (e == null || !e.isUsable) return null;
    return VoiceResult(
      customer: e.customer!,
      qtyLitres: e.qtyLitres ?? 0,
      status: e.skipped ? DeliveryStatus.skipped : DeliveryStatus.delivered,
    );
  }

  @override
  List<Object?> get props => [phase, transcript, entry];
}

/// Result handed back when he confirms a spoken entry.
final class VoiceResult extends Equatable {
  const VoiceResult({
    required this.customer,
    required this.qtyLitres,
    required this.status,
  });

  final Customer customer;
  final double qtyLitres;
  final DeliveryStatus status;

  @override
  List<Object?> get props => [customer, qtyLitres, status];
}
