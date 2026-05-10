class AuthSession {
  final String userId;
  final String? email;
  final String? name;

  const AuthSession({
    required this.userId,
    required this.email,
    required this.name,
  });
}
