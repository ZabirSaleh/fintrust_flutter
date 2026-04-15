import 'package:flutter/foundation.dart';

import '../../core/services/session_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/user_repository.dart';

class AuthProvider extends ChangeNotifier {
  final UserRepository userRepository;
  final AccountRepository accountRepository;
  final SessionService sessionService;

  AuthProvider({
    required this.userRepository,
    required this.accountRepository,
    required this.sessionService,
  });

  bool isInitializing = true;
  bool isLoggedIn = false;
  int? userId;
  String? email;
  String? error;

  Future<void> restoreSession() async {
    final session = await sessionService.loadSession();
    if (session != null) {
      userId = session['userId'] as int;
      email = session['email'] as String;
      isLoggedIn = true;
    }
    isInitializing = false;
    notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String fullName,
    required String password,
  }) async {
    error = null;
    final existing = await userRepository.findByEmail(email);
    if (existing != null) {
      error = 'Email already registered';
      notifyListeners();
      return false;
    }

    final user = await userRepository.create(
      email: email,
      fullName: fullName,
      password: password,
    );
    await accountRepository.createDefaultWallet(user.id!);
    return true;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    error = null;
    final user = await userRepository.findByEmail(email);
    if (user == null || user.password != password) {
      error = 'Invalid email or password';
      notifyListeners();
      return false;
    }

    userId = user.id;
    this.email = user.email;
    isLoggedIn = true;
    await sessionService.saveSession(userId: user.id!, email: user.email);
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await sessionService.clearSession();
    isLoggedIn = false;
    userId = null;
    email = null;
    notifyListeners();
  }
}
