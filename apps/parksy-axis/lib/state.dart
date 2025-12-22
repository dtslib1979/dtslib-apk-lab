/// FSM: ℤ₅ cyclic state machine
/// tap(): s → (s+1) mod 5

class AxisState {
  static const labels = ['Capture', 'Note', 'Build', 'Test', 'Publish'];
  static const int max = 5;

  int _idx = 0;

  int get index => _idx;
  String get label => labels[_idx];
  bool isActive(int i) => i == _idx;

  void next() => _idx = (_idx + 1) % max;
  void reset() => _idx = 0;
}
