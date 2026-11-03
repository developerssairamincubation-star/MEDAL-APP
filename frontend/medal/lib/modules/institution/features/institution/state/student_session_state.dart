// In-memory flags that last for one login session (cleared on login / logout).

class StudentSessionState {
  StudentSessionState._();

  /// Whether the "Level Up Your Impact" card was already shown this session.
  static bool impactCardShown = false;

  static void reset() {
    impactCardShown = false;
  }
}
