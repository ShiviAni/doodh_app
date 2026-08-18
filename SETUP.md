# Doodh Hisab — setup

Everything in the app is built. What remains is creating **your** Firebase project,
which needs an interactive Google login that only you can do.

Budget about 30 minutes, once.

---

## What this costs

**About ₹0 per month** at 50 houses — but this now needs the **Blaze plan with a
card on file**, because push notifications require Cloud Functions.

You stay far inside the free allowances that Blaze keeps:

| | Your monthly usage | Free allowance | Headroom |
|---|---|---|---|
| Function calls | ~1,600 | 2,000,000 | 1,250× |
| Firestore writes | ~1,600 | 600,000 | 375× |
| Firestore reads | ~60,000 | 1,500,000 | 25× |
| Storage | ~4 MB/year | 1 GB | 250× |

**Set a spend cap in Step 2b so this can never surprise you.** Login stays on
email/password rather than SMS, which would be a genuine per-message cost.

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

### Step 2b — Upgrade to Blaze, then cap the spend

Cloud Functions are what send your notifications, and they need Blaze.

1. Bottom-left of the console → **Upgrade** → Blaze → add a card.
2. **Immediately set a budget cap** so a mistake cannot cost you money:
   Google Cloud Console → **Billing → Budgets & alerts → Create budget** →
   amount **₹100/month**, alert at 50% / 90% / 100%.

At your volume the real bill should be ₹0 every month. The cap is there so that
stays true even if something goes wrong.

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
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## Step 4b — Deploy the notification functions

This is what buzzes your phone when he saves, and what writes the permanent
change history.

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

The first deploy takes a few minutes and may ask you to enable some Google Cloud
APIs — say yes. Three functions should appear: `onDeliveryWritten`,
`onPaymentWritten`, `onCustomerWritten`.

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
3. **Push** — lock your phone, close the app completely, then have him record a
   house. Your phone should buzz within a few seconds.
4. **Change alert** — open **History**, change a past entry from your own app,
   and confirm the new row reads "changed from X to Y" with your name and the
   reason on it.
5. **Money isolation** — log into the delivery app and confirm there is no screen
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

**Voice entry needs a speech recogniser on the phone.** Most Android phones have
one through the Google app; emulators usually do not. If the mic says "कुछ
सुनाई नहीं दिया" no matter what, that phone cannot do speech — the buttons still
work exactly as before, so nothing is lost.

**Voice may need internet unless you download the Hindi pack.** By default
Android sends speech to Google's servers, which will not work mid-round with no
signal. To make it work offline, on his phone go to **Settings → Google → All
services → Search, Assistant & Voice → Voice → Offline speech recognition** and
download **हिन्दी**. Worth doing before you hand the phone over — the rest of the
app is fully offline, and this is the one part that is not by default.

**The history is written on the server, not by the app.** Every entry in the
History tab is created by a Cloud Function reacting to the database change
itself. That is deliberate: a log the app keeps about its own behaviour is only
as honest as the app. This one records what actually reached the database.

**You will not be notified twice for one delivery.** His phone re-sends queued
entries when signal returns, sometimes more than once. The function compares the
old and new values and stays quiet when nothing actually changed.

**No notification arriving?** Check, in order: notification permission is granted
on your phone; you are logged in as the owner (delivery devices are never
registered); and `firebase functions:log` shows the trigger firing.
