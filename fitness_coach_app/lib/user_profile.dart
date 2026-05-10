import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  int grassBalance = 0;
  int capybaraFeedCount = 0;
  int lifetimeCorrectReps = 0;

  static const _kName = 'p_name';
  static const _kUsername = 'p_username';
  static const _kAvatar = 'p_avatar';
  static const _kExperience = 'p_experience';
  static const _kHasLaunched = 'has_launched';
  static const _kExerciseIndex = 'p_exercise_index';
  static const _kGrassBalance         = 'p_grass_balance';
  static const _kCapybaraFeedCount    = 'p_capy_feed_count';
  static const _kLifetimeCorrectReps  = 'p_lifetime_correct_reps';
  static const _kAuth0UserId = 'p_auth0_user_id';
  static const _kIsGuest = 'p_is_guest';

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

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  // ── Local (SharedPreferences) ─────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    hasEverLaunched = prefs.getBool(_kHasLaunched) ?? false;
    name = prefs.getString(_kName) ?? '';
    username = prefs.getString(_kUsername) ?? '';
    avatarIndex = prefs.getInt(_kAvatar) ?? 0;
    experience = prefs.getString(_kExperience) ?? 'Beginner';
    selectedExerciseIndex = prefs.getInt(_kExerciseIndex) ?? 0;
    grassBalance         = prefs.getInt(_kGrassBalance)         ?? 0;
    capybaraFeedCount    = prefs.getInt(_kCapybaraFeedCount)    ?? 0;
    lifetimeCorrectReps  = prefs.getInt(_kLifetimeCorrectReps)  ?? 0;
    auth0UserId = prefs.getString(_kAuth0UserId);
    isGuest = prefs.getBool(_kIsGuest) ?? true;
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

  // ── Firestore ─────────────────────────────────────────────────────────────

  Future<void> loadFromFirestore() async {
    if (auth0UserId == null) {
      debugPrint('[Firestore] loadFromFirestore skipped — auth0UserId is null');
      return;
    }
    debugPrint('[Firestore] loading doc: users/$auth0UserId');
    try {
      final doc = await _users.doc(auth0UserId).get();
      if (doc.exists) {
        final d = doc.data()!;
        name = (d['name'] as String?) ?? name;
        username = (d['username'] as String?) ?? username;
        avatarIndex = (d['avatarIndex'] as int?) ?? avatarIndex;
        experience = (d['experience'] as String?) ?? experience;
        selectedExerciseIndex =
            (d['selectedExerciseIndex'] as int?) ?? selectedExerciseIndex;
        grassBalance        = (d['grassBalance']        as int?) ?? grassBalance;
        capybaraFeedCount   = (d['capybaraFeedCount']   as int?) ?? capybaraFeedCount;
        lifetimeCorrectReps = (d['lifetimeCorrectReps'] as int?) ?? lifetimeCorrectReps;
        debugPrint('[Firestore] loaded successfully');
      } else {
        debugPrint('[Firestore] no existing doc — will still attempt migration');
      }

      // One-time migration: if lifetimeCorrectReps is 0, compute from session history.
      // This runs whether or not the user profile doc exists yet.
      if (lifetimeCorrectReps == 0) {
        await _migrateLifetimeReps();
      }

      await _saveToPrefs();
    } catch (e) {
      debugPrint('[Firestore] loadFromFirestore error: $e');
    }
  }

  Future<void> save() async {
    if (isGuest) return;
    await Future.wait([
      _saveToPrefs(),
      _saveToFirestore(),
    ]);
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    await prefs.setString(_kUsername, username);
    await prefs.setInt(_kAvatar, avatarIndex);
    await prefs.setString(_kExperience, experience);
    await prefs.setInt(_kExerciseIndex, selectedExerciseIndex);
    await prefs.setInt(_kGrassBalance,        grassBalance);
    await prefs.setInt(_kCapybaraFeedCount,   capybaraFeedCount);
    await prefs.setInt(_kLifetimeCorrectReps, lifetimeCorrectReps);
    await prefs.setBool(_kIsGuest, isGuest);
    if (auth0UserId != null) {
      await prefs.setString(_kAuth0UserId, auth0UserId!);
    } else {
      await prefs.remove(_kAuth0UserId);
    }
  }

  Future<void> _saveToFirestore() async {
    if (auth0UserId == null) {
      debugPrint('[Firestore] save skipped — auth0UserId is null');
      return;
    }
    debugPrint('[Firestore] saving doc: users/$auth0UserId');
    try {
      await _users.doc(auth0UserId).set({
        'name': name,
        'username': username,
        'avatarIndex': avatarIndex,
        'experience': experience,
        'selectedExerciseIndex': selectedExerciseIndex,
        'grassBalance':        grassBalance,
        'capybaraFeedCount':   capybaraFeedCount,
        'lifetimeCorrectReps': lifetimeCorrectReps,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[Firestore] saved successfully');
    } catch (e) {
      debugPrint('[Firestore] save error: $e');
    }
  }

  Future<void> saveCapybara() async {
    await _saveToPrefs();
    if (!isGuest) _saveToFirestore().ignore();
  }

  Future<void> _migrateLifetimeReps() async {
    if (auth0UserId == null) return;
    try {
      final sessions = await _users.doc(auth0UserId).collection('sessions').get();
      for (final doc in sessions.docs) {
        final lifts = doc.data()['lifts'] as List<dynamic>? ?? [];
        for (final lift in lifts) {
          lifetimeCorrectReps += (lift['correctCount'] as int? ?? 0);
        }
      }
      final grassEarned = lifetimeCorrectReps ~/ 10;
      grassBalance = (grassEarned - capybaraFeedCount).clamp(0, grassEarned);
      debugPrint('[Firestore] migrated lifetimeCorrectReps=$lifetimeCorrectReps, grassBalance=$grassBalance');
      _saveToFirestore().ignore();
    } catch (e) {
      debugPrint('[Firestore] migration error: $e');
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    hasEverLaunched = false;
    name = '';
    username = '';
    avatarIndex = 0;
    experience = 'Beginner';
    selectedExerciseIndex = 0;
    grassBalance = 0;
    capybaraFeedCount = 0;
    lifetimeCorrectReps = 0;
    isGuest = true;
    auth0UserId = null;
    email = null;
    // _kHasLaunched intentionally cleared — user must go through auth again
  }
}
