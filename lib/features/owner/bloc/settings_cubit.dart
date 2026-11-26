import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/fire_and_forget.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/member_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../auth/auth_service.dart';
import '../../notifications/push_service.dart';

part 'settings_state.dart';

/// The rate, the member list, and signing out.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this._settings,
    required this._members,
    required this._push,
    required this._auth,
  }) : super(const SettingsState()) {
    _subs = [
      _settings.watchRate().listen(
        (rate) => emit(state.copyWith(rate: rate, rateLoaded: true)),
        onError: addError,
      ),
      _members.watchAll().listen(
        (list) => emit(state.copyWith(members: list)),
        onError: addError,
      ),
    ];
  }

  final SettingsRepository _settings;
  final MemberRepository _members;
  final PushService _push;
  final AuthService _auth;
  late final List<StreamSubscription<Object?>> _subs;

  /// Ignores anything that is not a positive number.
  void setRate(String input) {
    final rate = Validators.parsePositive(input);
    if (rate == null) return;
    fireAndForget(_settings.setRate(rate));
  }

  /// Grants access to [email]. The account itself is created in the Firebase
  /// console; both steps are needed and the emails must match.
  ///
  /// Writes nothing when the email is not plausible.
  void addMember({
    required String email,
    required String name,
    required MemberRole role,
  }) {
    if (!Validators.isPlausibleEmail(email)) return;
    final normalised = email.trim().toLowerCase();
    final trimmedName = name.trim();
    fireAndForget(
      _members.upsert(
        Member(
          email: normalised,
          role: role,
          displayName: trimmedName.isEmpty ? normalised : trimmedName,
        ),
      ),
    );
  }

  /// Drops this device from the owner token list first. Otherwise it keeps
  /// receiving notifications for a dairy it is no longer signed in to.
  void signOut() => unawaited(_signOut());

  Future<void> _signOut() async {
    await _push.unregister();
    await _auth.signOut();
  }

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
