import 'package:shared_preferences/shared_preferences.dart';

class AppProfile {
  AppProfile._();
  static final AppProfile instance = AppProfile._();

  bool isGuest = true;
  bool hasEverLaunched = false;
  String? auth0UserId;
  String? email;

  String name = '';
  String username = '';
  int avatarIndex = 0;
  String experience = 'Beginner';
  int selectedExerciseIndex = 0;

  static const _kName = 'p_name';
  static const _kUsername = 'p_username';
  static const _kAvatar = 'p_avatar';
  static const _kExperience = 'p_experience';
  static const _kHasLaunched = 'has_launched';
  static const _kExerciseIndex = 'p_exercise_index';

  static const List<String> experiences = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Master',
  ];

  static const List<String> exercises = [
    'Squat',
    'Bench',
    'Deadlift',
    'Push-up',
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    hasEverLaunched = prefs.getBool(_kHasLaunched) ?? false;
    name = prefs.getString(_kName) ?? '';
    username = prefs.getString(_kUsername) ?? '';
    avatarIndex = prefs.getInt(_kAvatar) ?? 0;
    experience = prefs.getString(_kExperience) ?? 'Beginner';
    selectedExerciseIndex = prefs.getInt(_kExerciseIndex) ?? 0;
  }

  Future<void> setExercise(int index) async {
    selectedExerciseIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kExerciseIndex, index);
  }

  Future<void> markLaunched() async {
    hasEverLaunched = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasLaunched, true);
  }

  Future<void> save() async {
    if (isGuest) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    await prefs.setString(_kUsername, username);
    await prefs.setInt(_kAvatar, avatarIndex);
    await prefs.setString(_kExperience, experience);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    hasEverLaunched = false;
    name = '';
    username = '';
    avatarIndex = 0;
    experience = 'Beginner';
    selectedExerciseIndex = 0;
    isGuest = true;
    auth0UserId = null;
    email = null;
  }
}
