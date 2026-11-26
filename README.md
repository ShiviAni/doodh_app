# दूध हिसाब / Doodh Hisab

Daily milk delivery tracking for a ~50-house dairy round. One app, two roles.

**New here? Read [SETUP.md](SETUP.md)** — the code is complete, but the Firebase
project has to be created by you.

## The two roles

**Delivery** — a list of every house, tappable in any order. He hands over the
milk, then taps that house and confirms; the quantity is pre-filled from the
usual amount, so a normal house is one tap. A mic button records by voice
instead — "राम कुमार ढाई लीटर" — with a confirmation step before saving. Works
entirely offline; entries sync when signal returns. Sees no money at all.

**Owner** — live Today view that updates the moment he taps save, a permanent
change history, day/week/month/year reports in litres and rupees, customer
management, per-house balances, WhatsApp bills and CSV export. Push
notifications arrive with the phone locked and the app closed.

## How "he can't see the money" actually works

Not by hiding buttons — a modified APK would unhide them. Two structural
choices do the work:

1. **No rupee value is stored anywhere the delivery role can read.** Firestore
   grants access per *document*, never per *field*, so a balance on the customer
   document would be readable the instant he read the customer's name. The rate,
   payments, balances and bills live in separate owner-only collections instead.
   He is never even sent the ₹/litre rate.

2. **`firestore.rules` enforces it server-side.** See the access table there.

## How offline works

Firestore's local persistence keeps the pending write queue on disk, so entries
survive an app kill and replay on reconnect. Delivery documents use a
deterministic ID — `yyyy-MM-dd_customerId` — so a replayed write overwrites one
document instead of creating a duplicate. The UI never awaits a write, because
that future does not complete while offline.

## Voice entry

Hindi milk quantities are mostly irregular words rather than digits: डेढ़ is
1.5 and ढाई is 2.5, and neither contains the word for one or two. A general
number parser cannot reach them, so `voice/voice_parser.dart` carries an
explicit table, matched longest-phrase-first — otherwise "साढ़े तीन" reads as
"तीन" and quietly under-records by half a litre every time.

Names are matched per-token against both spellings, because recognisers
routinely return a first name only. A partial match is surfaced as "name
uncertain" rather than saved silently: a wrong house is a wrong bill at the end
of the month, so voice entry always ends in an explicit confirmation.

## Notifications and history

Both are driven by Cloud Functions triggering on the Firestore write itself,
not by the app reporting on its own behaviour. That distinction is the point: a
log the app keeps about itself is only as trustworthy as the app. This one
records what actually reached the database.

A delivery that is merely re-synced — which a patchy connection does more than
once — is compared against its previous value and stays silent, so one delivery
never buzzes the phone twice. Edits are reported differently from first
records: "changed from 2 L to 3 L" is the thing worth interrupting someone for.

## Layout

```
lib/
  core/        theme (large-touch sizing), bilingual strings, date/money formats, DI
  data/
    models/        Customer, Delivery, Payment, Bill, Member
    repositories/  Firestore access + ReportCalculator (pure, fully unit-tested)
  features/
    auth/        email login, role resolution
    delivery/    house list, entry card, stepper, sync badge, cash log
      voice/     speech service + Hindi/English quantity and name parser
    owner/       today, history, reports, customers, money, settings
    notifications/ FCM registration + foreground display
    */bloc/      one Cubit (or Bloc) per screen: streams, writes, derived figures
test/
  bloc/          bloc_test suites for every cubit
  unit/, widget/
patrol_test/     on-device integration tests (Patrol), run against the demo app
functions/       Cloud Functions: change history + push (Node)
firestore.rules  the security boundary
```

State is managed with **flutter_bloc**. Widgets never talk to a repository:
each screen's cubit owns its Firestore listeners and writes, and the widget
only renders its state. See `.github/REVIEW_GUIDELINES.md` for the rules.

## Commands

```bash
flutter test                                  # unit, widget and bloc tests
flutter analyze --fatal-infos lib test patrol_test
echo N | dart run bloc_tools:bloc lint lib    # bloc rules
dart format lib test patrol_test
patrol test                                   # on-device tests; needs an emulator
cd functions && npm test                      # Cloud Functions tests
flutter run -t lib/main_demo.dart             # whole app on seeded data, no Firebase
flutter run
```

`patrol test` needs `dart pub global activate patrol_cli` once, and `adb` on
your `PATH`.

## CI

GitHub Actions, in `.github/workflows/`:

| Workflow | When | What |
| --- | --- | --- |
| `ci.yml` | every push and PR | format, `flutter analyze --fatal-infos`, bloc lint; tests with a coverage floor; Patrol on an Android emulator (PRs into `main`); demo APK build; Cloud Functions lint, tests and `npm audit`; gitleaks secret scan, committed-key check, dependency review; CodeQL on the functions |
| `claude-review.yml` | PR opened or updated | Claude reviews the diff against `.github/REVIEW_GUIDELINES.md` and posts inline comments plus a summary. Advisory, not a merge gate |
| `release.yml` | tag `v*.*.*` | signed, obfuscated Play Store bundle |

Dependabot (`.github/dependabot.yml`) opens weekly update PRs for pub, npm and
the actions themselves.

### One-time setup

1. **Repository secret `ANTHROPIC_API_KEY`**, and install the Claude GitHub app
   on the repo (`/install-github-app` in Claude Code does both). Without it the
   review job fails; the CI checks are unaffected.
2. **Branch protection on `main`**: require a pull request with one approval,
   and require the checks *Format, analyze, bloc lint*, *Unit and widget tests*,
   *Patrol integration tests (Android)*, *Build debug APK*, *Cloud Functions* and
   *Security checks*.
3. **Release secrets** (only when you start shipping from CI), in a `release`
   environment: `GOOGLE_SERVICES_JSON_BASE64`, `ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
   Locally the same values go in `android/key.properties` (gitignored). Without
   it, release builds are debug-signed and must not be uploaded.
4. **CodeQL** is free on public repos. On a private repo it needs GitHub
   Advanced Security; if you don't have that, delete the `codeql` job.

The coverage floor (`MIN_COVERAGE` in `ci.yml`) was set just under the measured
69.5%. Raise it as coverage grows.
