## What and why

<!-- What does this change, and why is it needed? Link the issue if there is one. -->

## How it was tested

<!-- Unit / bloc / widget / Patrol tests added, and anything checked by hand on a device. -->

## Checklist

- [ ] Data access goes through a cubit/bloc, not a widget
- [ ] Firestore writes in UI paths use `fireAndForget`
- [ ] New or changed cubits have `bloc_test` tests
- [ ] New user flows or native interactions have a Patrol test
- [ ] `firestore.rules` / `storage.rules` updated if data shape or access changed
- [ ] User-facing text is in `strings.dart` in Hindi and English
- [ ] No secrets, keys or personal data in code or logs
