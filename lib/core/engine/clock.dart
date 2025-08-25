class ClockEngine {
  int secondsLeft;
  bool running = false;

  ClockEngine({this.secondsLeft = 15 * 60});

  void reset(int seconds) {
    secondsLeft = seconds;
    running = false;
  }

  /// Returns true when the timer reaches 0.
  bool tick() {
    if (!running) return false;
    if (secondsLeft > 0) secondsLeft -= 1;
    return secondsLeft == 0;
  }
}