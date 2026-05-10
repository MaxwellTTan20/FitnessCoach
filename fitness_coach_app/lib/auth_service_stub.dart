import 'auth_session.dart';

class AppAuthService {
  AppAuthService._();

  static final AppAuthService instance = AppAuthService._();

  Future<AuthSession?> restoreSession() async => null;

  Future<AuthSession> signInWithGoogle() {
    throw UnsupportedError('Auth is not supported on this platform.');
  }

  Future<void> signOut() async {}
}
