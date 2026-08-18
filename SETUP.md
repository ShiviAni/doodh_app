# Doodh Hisab — setup

Everything in the app is built. What remains is creating **your** Firebase project,
which needs an interactive Google login that only you can do.

Budget about 30 minutes, once.

---

## What this costs

**₹0 per month**, permanently, at 50 houses. The design stays on Firebase's free
Spark plan and needs no credit card:

| | Your daily usage | Free limit | Headroom |
|---|---|---|---|
| Writes | ~50 | 20,000 | 400× |
| Reads | ~2,000 | 50,000 | 25× |
| Storage | ~4 MB/year | 1 GB | 250× |

Two things were deliberately avoided to keep it there: **Cloud Functions** and
**Phone/SMS login** — each of those forces the paid Blaze plan.

---

## Step 1 — Install the tools

This machine has no `node`/`npm`, so use the standalone installer:

```bash
curl -sL https://firebase.tools | bash          # asks for your Mac password
dart pub global activate flutterfire_cli
```

If `flutterfire` is not found afterwards, add it to your PATH:

```bash
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc && source ~/.zshrc
```

## Step 2 — Create the Firebase project

```bash
firebase login          # opens a browser, sign in with your Google account
```

Then go to <https://console.firebase.google.com> and:

1. **Add project** → name it `doodh-hisab` → you can turn Google Analytics **off**.
2. **Build → Firestore Database** → Create database → **production mode** →
   location `asia-south1` (Mumbai — closest, so the app feels fastest).
3. **Build → Authentication** → Get started → enable **Email/Password**.
   Leave "Email link" off.
4. **Build → Storage** → Get started (only needed if you want house photos).

## Step 3 — Connect the app

From `~/AndroidStudioProjects/doodh_app`:

```bash
flutterfire configure
```

Pick the `doodh-hisab` project and select **android** and **ios**. This overwrites
`lib/firebase_options.dart` with your real keys.

## Step 4 — Upload the security rules

**Do not skip this.** The rules are what stop the delivery person from reading the
money. Until they are uploaded, your database is wide open.

```bash
firebase deploy --only firestore:rules,storage
```

## Step 5 — Create the two accounts

In the Firebase console, **Authentication → Users → Add user**. Create two:

| | Email | Password |
|---|---|---|
| You | `owner@doodhhisab.com` | pick a strong one |
| Delivery person | `delivery@doodhhisab.com` | pick a simple one you type for him |

The emails do not need to be real addresses — nothing is ever sent to them. They
are just usernames.

## Step 6 — Seed yourself as the owner

The app reads roles from Firestore, and no roles exist yet. Create the first one
by hand, in the console: **Firestore Database → Start collection**.

- Collection ID: `dairies`
- Document ID: `main`
- Add one field: `name` (string) = `Doodh Hisab`

Then inside that document, **Start collection**:

- Collection ID: `members`
- Document ID: `owner@doodhhisab.com`  ← must exactly match the email above
- Fields:
  - `role` (string) = `owner`
  - `displayName` (string) = your name
  - `active` (boolean) = `true`

That is the only manual database work. Once you can log in as owner, you add the
delivery person from **Settings → Members** inside the app.

## Step 7 — Run it

```bash
flutter run
```

Log in as the owner. Then:

1. **Settings** → set your ₹/litre rate.
2. **Settings → Members → Add** → `delivery@doodhhisab.com`, role Delivery.
3. **Customers** → add your 50 houses. Set **Order on route** to match the
   sequence he actually walks — that is what puts the cards in the right order,
   and it is the single biggest thing that makes his round fast.

## Step 8 — Set up his phone

```bash
flutter build apk --release
```

The file lands in `build/app/outputs/flutter-apk/app-release.apk`. Send it to his
phone, install it, and **you** type the delivery email and password in once. He
stays signed in from then on and never sees a login screen again.

---

## Checking it actually works

Worth doing before you rely on it:

1. **Offline** — put his phone in airplane mode, record all 50 houses, force-kill
   the app, reopen it. The entries must still be there. Turn the network back on
   and confirm all 50 appear on your dashboard with no duplicates.
2. **Live sync** — with both phones open, have him mark one house. Your Today
   total should move within a second or two.
3. **Money isolation** — log into the delivery app and confirm there is no screen
   anywhere showing a rate, a total, or a due.

---

## Things worth knowing

**Changing the rate re-prices history.** Bills are computed from litres × current
rate rather than stored as fixed amounts. Correcting a typo in the rate is
therefore instant and correct — but a genuine mid-year price rise would restate
past months too. If your price ever actually changes, tell me and I will add
dated rate history.

**He can record today and yesterday, nothing else.** Yesterday is allowed so a
round that runs past midnight, or a phone that was offline overnight, still
works. Correcting anything older is yours to do, and every correction is stamped
with who changed it, when, and why.

**Cash he collects does not count until you approve it.** It shows up in
**Money → Pending approvals**. This is deliberate: an unverified doorstep claim
should never be able to clear a real due on its own.

**Customers are deactivated, never deleted** — otherwise past months' bills would
silently change.
