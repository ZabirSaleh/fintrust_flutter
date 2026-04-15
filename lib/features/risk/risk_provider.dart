import 'package:flutter/foundation.dart';

import '../../data/models/risk_event_model.dart';
import '../../data/repositories/risk_repository.dart';

class RiskProvider extends ChangeNotifier {
  final RiskRepository riskRepository;

  RiskProvider({required this.riskRepository});

  bool loading = false;
  String? error;
  List<RiskEventModel> events = [];

  Future<void> load(int userId) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      events = await riskRepository.getByUserId(userId);
    } catch (e) {
      error = 'Failed to load risk events: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}