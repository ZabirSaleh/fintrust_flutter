import 'package:flutter/foundation.dart';

import '../../data/models/account_model.dart';
import '../../data/repositories/account_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final AccountRepository accountRepository;

  DashboardProvider({required this.accountRepository});

  bool loading = false;
  String? error;
  List<AccountModel> accounts = [];

  Future<void> loadAccounts(int userId) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      accounts = await accountRepository.getByUserId(userId);
    } catch (e) {
      error = 'Failed to load accounts: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}