sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.accessToken,
    required this.teacherID,
  });
  final String accessToken;
  final String teacherID;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthNetworkError extends AuthState {
  const AuthNetworkError();
}
