import 'package:flutter/foundation.dart';

class HistoryProvider extends ChangeNotifier {
  bool loading = false;

  void loadHistory() {
    loading = true;
    notifyListeners();

    // Future transaction loading logic

    loading = false;
    notifyListeners();
  }
}
