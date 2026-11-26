# Review guidelines

Used by human reviewers and by the Claude review workflow
(`.github/workflows/claude-review.yml`). Formatting, lints and bloc lint rules
are enforced by CI, so reviews do not repeat them.

Severity: **blocker** (must fix before merge), **should-fix** (fix now unless
there is a stated reason not to), **nit** (optional).

## 1. State management: bloc

- Every screen that reads or writes data has a Cubit (or a Bloc when there
  are real events, as in `VoiceEntryBloc`). Files live in
  `features/<feature>/bloc/` as `<name>_cubit.dart` with `<name>_state.dart`
  as a `part`.
- **Widgets never call repositories.** No `sl<SomeRepository>()` outside a
  `BlocProvider(create: ...)`, and no `StreamBuilder` over a repository stream.
  (blocker)
- States are immutable, `final class`, extend `Equatable`, list every field in
  `props`, and offer `copyWith` when there are several fields.
- Cubits do not import Flutter, hold a `BuildContext`, or navigate. Navigation
  and snackbars are done with `BlocListener` / `BlocConsumer`.
- Public cubit methods return `void` (bloc lint enforces this). The UI does not
  await cubit work.
- Every `StreamSubscription` is cancelled in `close()`. Every timer too.
  (blocker)
- Sheets and dialogs are new routes: pass the cubit with `BlocProvider.value`.
- `setState` is fine for purely local UI: text controllers, a toggle, a form
  stepper, the selected tab. Anything that touches data is not local.

## 2. Offline-first writes

- Firestore writes are **not awaited** in UI paths. Offline, the future only
  completes when the server acknowledges, which would freeze the screen. Use
  `fireAndForget(...)` from `core/utils/fire_and_forget.dart`. (blocker)
- Writes must be idempotent where they can be replayed. Deliveries use the
  deterministic id `DateKeys.deliveryId(dayKey, customerId)`.
- No `limit`-less query over a growing collection in a hot path.

## 3. Naming

- Dart conventions: `UpperCamelCase` types, `lowerCamelCase` members,
  `snake_case.dart` files, private with `_`.
- Suffixes say what a class is: `*Cubit`, `*Bloc`, `*State`, `*Event`,
  `*Repository`, `*Service`, `*Page` (a full screen), `*Sheet` (bottom sheet).
- Events are past tense or requests: `VoiceListenRequested`.
- Booleans read as questions: `isComplete`, `canSubmit`, `hasCustomer`.
- Names describe the domain, not the widget tree: `pendingApprovals`, not
  `list2`.

## 4. Performance

- No work in `build()` that could be done once per state: aggregation, sorting,
  grouping and parsing belong in the cubit or as `late final` fields on the
  state.
- Never create a stream inside `build()`. That re-subscribes on every rebuild.
- `const` constructors wherever possible. `buildWhen` on a `BlocBuilder` that
  only needs part of the state.
- Long lists use `ListView.builder` / `.separated`, not a `Column` of all items.
- Images from the network have a size and a placeholder.

## 5. Security and privacy

- **Firestore and Storage rules are the real access control.** Any change to
  data shape, a new collection, or a new role-dependent screen needs a matching
  `firestore.rules` change, and the PR must say so. Hiding a button is not
  security. (blocker if missing)
- The delivery role must never be able to read payments, the rate, or another
  member's data. Check the rules, not just the UI.
- No secrets, tokens, keystores, `google-services.json` or service-account
  files in the repo. CI scans for them, but review the diff anyway.
- No personal data (names, phone numbers, emails) in logs, analytics or error
  messages. `debugPrint` of a whole document is a finding.
- Validate input at the cubit (`core/utils/validators.dart`), not only in the
  form.
- URLs built from user data are encoded (`Uri.encodeComponent`).
- Cloud Functions: check auth and input on every callable or trigger, and keep
  them idempotent, since triggers can fire more than once.

## 6. Tests

- A new or changed cubit/bloc comes with a `bloc_test` in `test/bloc/`.
  (should-fix; blocker for money or billing logic)
- A bug fix comes with a test that fails without the fix.
- A new user flow or native interaction (permissions, sharing, notifications)
  gets a Patrol test in `patrol_test/`.
- Tests are never weakened, skipped or deleted to make CI pass.

## 7. Localisation and accessibility

- User-facing text goes through `S` (`core/l10n/strings.dart`) with both Hindi
  and English. Hard-coded English in a widget is a finding.
- Tap targets are at least 48dp. Icon-only buttons have a `tooltip`.
- Colour is never the only signal (delivered/skipped/pending also differ in
  icon or text).

## 8. General

- The PR description says what changed and why, and how it was tested.
- Comments explain *why*, not *what*.
- No dead code, commented-out code or unexplained `// ignore:`.
