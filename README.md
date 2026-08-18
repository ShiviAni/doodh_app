# दूध हिसाब / Doodh Hisab

Daily milk delivery tracking for a ~50-house dairy round. One app, two roles.

**New here? Read [SETUP.md](SETUP.md)** — the code is complete, but the Firebase
project has to be created by you.

## The two roles

**Delivery** — one screen, one job. A full-screen card per house in walking
order, quantity pre-filled, one big green button to confirm. Works entirely
offline; entries sync when signal returns. Sees no money at all.

**Owner** — live Today view that updates the moment he taps save, day/week/
month/year reports in litres and rupees, customer management, per-house
balances, WhatsApp bills and CSV export.

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

## Layout

```
lib/
  core/        theme (large-touch sizing), bilingual strings, date/money formats, DI
  data/
    models/        Customer, Delivery, Payment, Bill, Member
    repositories/  Firestore access + ReportCalculator (pure, fully unit-tested)
  features/
    auth/        email login, role resolution
    delivery/    round controller, delivery card, stepper, sync badge, cash log
    owner/       today, reports, customers, money, settings
firestore.rules  the security boundary
```

## Commands

```bash
flutter test        # 42 tests
flutter analyze     # clean
flutter run
flutter build apk --release
```
