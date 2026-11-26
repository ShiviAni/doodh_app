part of 'settings_cubit.dart';

final class SettingsState extends Equatable {
  const SettingsState({
    this.rate = SettingsRepository.defaultRate,
    this.rateLoaded = false,
    this.members = const [],
  });

  final double rate;

  /// False until the stored rate has arrived, so the editor is not prefilled
  /// with the default and then saved over the real value.
  final bool rateLoaded;
  final List<Member> members;

  SettingsState copyWith({
    double? rate,
    bool? rateLoaded,
    List<Member>? members,
  }) => SettingsState(
    rate: rate ?? this.rate,
    rateLoaded: rateLoaded ?? this.rateLoaded,
    members: members ?? this.members,
  );

  @override
  List<Object?> get props => [rate, rateLoaded, members];
}
