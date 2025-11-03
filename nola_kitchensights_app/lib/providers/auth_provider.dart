import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final String userName;
  final List<int> storeIds;
  const AuthState({required this.userName, required this.storeIds});

  AuthState copyWith({String? userName, List<int>? storeIds}) =>
      AuthState(userName: userName ?? this.userName,
                storeIds: storeIds ?? this.storeIds);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(): super(const AuthState(userName: 'Convidado', storeIds: [1,2]));

  void impersonate({required String name, required List<int> storeIds}) {
    state = state.copyWith(userName: name, storeIds: storeIds);
  }
}

// providers
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
