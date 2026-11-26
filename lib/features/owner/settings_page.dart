import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../core/utils/validators.dart';
import '../../data/models/member.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../auth/auth_service.dart';
import '../notifications/push_service.dart';
import 'bloc/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SettingsCubit(
      settings: sl<SettingsRepository>(),
      members: sl<MemberRepository>(),
      push: sl<PushService>(),
      auth: sl<AuthService>(),
    ),
    child: _SettingsView(session: session),
  );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return ListView(
      padding: const EdgeInsets.all(Sizes.gap),
      children: [
        _SectionTitle(s.ratePerLitre),
        const _RateEditor(),

        const SizedBox(height: Sizes.gapLarge),
        _SectionTitle(s.language),
        SegmentedButton<AppLanguage>(
          segments: const [
            ButtonSegment(value: AppLanguage.hindi, label: Text('हिन्दी')),
            ButtonSegment(value: AppLanguage.english, label: Text('English')),
          ],
          selected: {s.lang},
          showSelectedIcon: false,
          onSelectionChanged: (sel) => LanguageScope.set(context, sel.first),
        ),

        const SizedBox(height: Sizes.gapLarge),
        _SectionTitle(s.members),
        const _MembersList(),

        const SizedBox(height: Sizes.gapLarge),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(session.email),
          subtitle: Text(session.member?.displayName ?? ''),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: Text(s.logout),
          onPressed: context.read<SettingsCubit>().signOut,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Sizes.gap - 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: Sizes.bodyText,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The ₹/litre rate.
///
/// Changing it re-prices every report and bill, including past months, because
/// bills are computed from litres rather than stored as fixed amounts. That is
/// the right behaviour for a single-rate dairy correcting a typo — but it does
/// mean a genuine mid-year price change would restate history, so the warning
/// below is deliberate.
class _RateEditor extends StatefulWidget {
  const _RateEditor();

  @override
  State<_RateEditor> createState() => _RateEditorState();
}

/// Holds only the text controller; the rate itself comes from
/// [SettingsCubit].
class _RateEditorState extends State<_RateEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    final cubit = context.read<SettingsCubit>();

    // Prefill once, when the stored rate first arrives. Later updates must
    // not overwrite what the owner is in the middle of typing.
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (prev, next) => !prev.rateLoaded && next.rateLoaded,
      listener: (_, state) => _controller.text = state.rate.toStringAsFixed(0),
      buildWhen: (prev, next) => prev.rate != next.rate,
      builder: (context, state) {
        final rate = state.rate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                ),
                const SizedBox(width: Sizes.gap),
                FilledButton(
                  onPressed: () {
                    cubit.setRate(_controller.text);
                    FocusScope.of(context).unfocus();
                  },
                  child: Text(s.save),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hindi
                  ? 'अभी: ${Fmt.money(rate)} प्रति लीटर। भाव बदलने पर पुराने महीनों का हिसाब भी नए भाव से बनेगा।'
                  : 'Currently ${Fmt.money(rate)} per litre. Changing it also re-prices past months.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Who can sign in, and as what.
///
/// Adding a member here only grants access — the account itself is created in
/// the Firebase console. Both steps are needed, and the email must match.
class _MembersList extends StatelessWidget {
  const _MembersList();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (prev, next) => prev.members != next.members,
      builder: (context, state) {
        final members = state.members;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final m in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  m.isOwner
                      ? Icons.admin_panel_settings
                      : Icons.delivery_dining,
                  color: m.isOwner ? AppTheme.seed : AppTheme.confirm,
                ),
                title: Text(m.displayName),
                subtitle: Text(m.email),
                trailing: Text(
                  m.isOwner
                      ? (hindi ? 'मालिक' : 'Owner')
                      : (hindi ? 'सप्लाई' : 'Delivery'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: Text(s.add),
              onPressed: () => _MemberEditor.show(context),
            ),
          ],
        );
      },
    );
  }
}

class _MemberEditor extends StatefulWidget {
  const _MemberEditor();

  static Future<void> show(BuildContext context) {
    // A new route, outside the page's provider: hand the cubit across.
    final cubit = context.read<SettingsCubit>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _MemberEditor()),
    );
  }

  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  MemberRole _role = MemberRole.delivery;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    return Padding(
      padding: EdgeInsets.only(
        left: Sizes.gapLarge,
        right: Sizes.gapLarge,
        top: Sizes.gapLarge,
        bottom: MediaQuery.of(context).viewInsets.bottom + Sizes.gapLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.members,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: Sizes.bodyText + 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sizes.gap),
          Text(
            hindi
                ? 'पहले Firebase console में इस ईमेल का खाता बनाएं, फिर यहाँ जोड़ें।'
                : 'Create the account in the Firebase console first, then add the same email here.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Sizes.gap),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(labelText: s.email),
          ),
          const SizedBox(height: Sizes.gap),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: s.customerName),
          ),
          const SizedBox(height: Sizes.gap),
          SegmentedButton<MemberRole>(
            segments: [
              ButtonSegment(
                value: MemberRole.delivery,
                label: Text(hindi ? 'सप्लाई' : 'Delivery'),
              ),
              ButtonSegment(
                value: MemberRole.owner,
                label: Text(hindi ? 'मालिक' : 'Owner'),
              ),
            ],
            selected: {_role},
            showSelectedIcon: false,
            onSelectionChanged: (sel) => setState(() => _role = sel.first),
          ),
          const SizedBox(height: Sizes.gapLarge),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(s.save),
            onPressed: () {
              if (!Validators.isPlausibleEmail(_email.text)) return;
              context.read<SettingsCubit>().addMember(
                email: _email.text,
                name: _name.text,
                role: _role,
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
