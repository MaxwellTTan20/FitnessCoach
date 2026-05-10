// Holds the currently active workout plan during a record session.
// Set before navigating to RecordPage; cleared when the session finishes.

class WorkoutGoal {
  final String exercise; // must match an entry in AppProfile.exercises
  final int targetReps; // total correct reps goal (sets × reps)
  const WorkoutGoal({required this.exercise, required this.targetReps});
}

class ActiveWorkout {
  final String name;
  final List<WorkoutGoal> goals;
  const ActiveWorkout({required this.name, required this.goals});
}

class WorkoutState {
  WorkoutState._();
  static final WorkoutState instance = WorkoutState._();

  ActiveWorkout? activeWorkout;
}
