import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/models/customer.dart';
import '../../../../data/models/delivery.dart';
import '../speech_service.dart';
import '../voice_parser.dart';

part 'voice_entry_event.dart';
part 'voice_entry_state.dart';

/// Speak-to-record: "राम कुमार ढाई लीटर".
///
/// Never saves by itself. It only works out what was said; the sheet always
/// asks for an explicit confirmation, because speech recognition of Indian
/// names is unreliable enough that a silent save would eventually put milk
/// against the wrong house, and a wrong house is a wrong bill.
class VoiceEntryBloc extends Bloc<VoiceEntryEvent, VoiceEntryState> {
  VoiceEntryBloc({
    required this._speech,
    required this._customers,
    required this._localeId,
    this._fixedCustomer,
    this._firstWordTimeout = const Duration(seconds: 9),
  }) : super(const VoiceEntryState()) {
    on<VoiceListenRequested>(_onListenRequested);
    on<_VoiceTranscriptReceived>(_onTranscript);
    on<_VoiceNothingHeard>(_onNothingHeard);
  }

  static const _parser = VoiceParser();

  final SpeechService _speech;
  final List<Customer> _customers;
  final String _localeId;

  /// Set when opened from a house's own card. Then only the quantity is
  /// listened for and the name is not second-guessed.
  final Customer? _fixedCustomer;

  /// How long to wait for the first word before giving up.
  ///
  /// A device with no speech service reports itself available and then never
  /// returns a result, so without this the sheet would sit on "speak now"
  /// forever while he talks at it.
  final Duration _firstWordTimeout;

  Timer? _watchdog;

  Future<void> _onListenRequested(
    VoiceListenRequested event,
    Emitter<VoiceEntryState> emit,
  ) async {
    emit(const VoiceEntryState());
    final ok = _speech.isAvailable || await _speech.initialise();
    if (!ok) {
      emit(const VoiceEntryState(phase: VoicePhase.unavailable));
      return;
    }

    emit(const VoiceEntryState(phase: VoicePhase.listening));

    _watchdog?.cancel();
    _watchdog = Timer(_firstWordTimeout, () {
      if (isClosed || state.transcript.isNotEmpty) return;
      unawaited(_speech.cancel());
      add(const _VoiceNothingHeard());
    });

    await _speech.listen(
      localeId: _localeId,
      onError: (_) {
        if (!isClosed) add(const _VoiceNothingHeard());
      },
      onResult: (text, isFinal) {
        if (!isClosed) add(_VoiceTranscriptReceived(text, isFinal: isFinal));
      },
    );
  }

  void _onTranscript(
    _VoiceTranscriptReceived event,
    Emitter<VoiceEntryState> emit,
  ) {
    if (event.text.isNotEmpty) _watchdog?.cancel();
    emit(
      VoiceEntryState(
        phase: event.isFinal ? VoicePhase.heard : VoicePhase.listening,
        transcript: event.text,
        entry: _interpret(event.text),
      ),
    );
  }

  void _onNothingHeard(
    _VoiceNothingHeard event,
    Emitter<VoiceEntryState> emit,
  ) {
    _watchdog?.cancel();
    emit(
      VoiceEntryState(
        phase: VoicePhase.heardNothing,
        transcript: state.transcript,
        entry: state.entry,
      ),
    );
  }

  /// On a card the house is already known, so only a quantity is looked for.
  VoiceEntry _interpret(String text) {
    final fixed = _fixedCustomer;
    if (fixed == null) return _parser.parse(text, _customers);

    final qty = _parser.parseQuantity(text);
    return VoiceEntry(
      transcript: text,
      customer: fixed,
      qtyLitres: qty,
      skipped: qty == 0,
      nameConfidence: 1,
    );
  }

  @override
  Future<void> close() async {
    _watchdog?.cancel();
    await _speech.cancel();
    return super.close();
  }
}
