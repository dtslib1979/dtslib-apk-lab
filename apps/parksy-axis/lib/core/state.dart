/// FSM: state ∈ ℤ₅
/// tap() → (s+1) mod 5

const List<String> stages = [
  'Capture',
  'Note',
  'Build',
  'Test',
  'Publish',
];

int currentStage = 0;

void nextStage() {
  currentStage = (currentStage + 1) % 5;
}

void resetStage() {
  currentStage = 0;
}
