import 'package:auth0_flutter/auth0_flutter_web.dart';

import 'auth_config.dart';
import 'auth_session.dart';

class AppAuthService {
  AppAuthService._()
    : _auth0 = Auth0Web(
        kAuth0Domain,
        kAuth0ClientId,
        redirectUrl: Uri.base.origin,
        cacheLocation: CacheLocation.localStorage,
      );

  static final AppAuthService instance = AppAuthService._();

  final Auth0Web _auth0;

  Future<AuthSession?> restoreSession() async {
    final credentials = await _auth0.onLoad(
      cacheLocation: CacheLocation.localStorage,
    );
    if (credentials == null) return null;

    return AuthSession(
      userId: credentials.user.sub,
      email: credentials.user.email,
      name: credentials.user.name,
    );
  }

  Future<AuthSession> signInWithGoogle() async {
    final credentials = await _auth0.loginWithPopup(
      parameters: {'connection': 'google-oauth2'},
    );

    return AuthSession(
      userId: credentials.user.sub,
      email: credentials.user.email,
      name: credentials.user.name,
    );
  }

  Future<void> signOut() async {
    await _auth0.logout(returnToUrl: Uri.base.origin);
  }
}
