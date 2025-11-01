import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final bool isLoggedIn;
  final String userName;
  final List<int> storeIds;

  AuthState({
    this.isLoggedIn = false,
    this.userName = '',
    this.storeIds = const [],
  });

  AuthState.loggedIn({
    required this.userName,
    required this.storeIds,
  }) : isLoggedIn = true;

  AuthState copyWith({
    bool? isLoggedIn,
    String? userName,
    List<int>? storeIds,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userName: userName ?? this.userName,
      storeIds: storeIds ?? this.storeIds,
    );
  }
}

// Mock: assume que o usuário está logado como Maria
final authProvider = Provider<AuthState>((ref) {
  return AuthState.loggedIn(
    userName: 'Maria',
    storeIds: [1, 2, 3],
  );
});