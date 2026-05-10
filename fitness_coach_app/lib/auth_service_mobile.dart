import 'package:auth0_flutter/auth0_flutter.dart';

import 'auth_config.dart';
import 'auth_session.dart';

class AppAuthService {
  AppAuthService._() : _auth0 = Auth0(kAuth0Domain, kAuth0ClientId);

  static final AppAuthService instance = AppAuthService._();

  final Auth0 _auth0;

  Future<AuthSession?> restoreSession() async {
    final hasCredentials = await _auth0.credentialsManager
        .hasValidCredentials();
    if (!hasCredentials) return null;

    final credentials = await _auth0.credentialsManager.credentials();
    return AuthSession(
      userId: credentials.user.sub,
      email: credentials.user.email,
      name: credentials.user.name,
    );
  }

  Future<AuthSession> signInWithGoogle() async {
    final credentials = await _auth0
        .webAuthentication(scheme: kAuth0Scheme)
        .login(parameters: {'connection': 'google-oauth2'});

    return AuthSession(
      userId: credentials.user.sub,
      email: credentials.user.email,
      name: credentials.user.name,
    );
  }

  Future<void> signOut() async {
    await _auth0.webAuthentication(scheme: kAuth0Scheme).logout();
    await _auth0.credentialsManager.clearCredentials();
  }
}
