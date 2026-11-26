/// Starts a Firestore write without waiting for it.
///
/// With offline persistence on, a write's future completes only once the
/// server acknowledges it. With no signal that can take hours, so awaiting it
/// would freeze the screen. The write is already in the on-disk queue the
/// moment the call returns, and Firestore replays it on reconnect.
///
/// An error here means the write is still pending, not lost; the sync badge
/// is what surfaces that to the user, so the error is deliberately swallowed.
void fireAndForget(Future<void> write) {
  write.ignore();
}
