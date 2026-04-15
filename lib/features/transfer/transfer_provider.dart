import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/utils/risk_calculator.dart';
import '../../data/models/risk_event_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/risk_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class TransferProvider extends ChangeNotifier {
  final AccountRepository accountRepository;
  final TransactionRepository transactionRepository;
  final RiskRepository riskRepository;

  TransferProvider({
    required this.accountRepository,
    required this.transactionRepository,
    required this.riskRepository,
  });

  bool loading = false;
  String? message;
  RiskResult? lastRiskResult;
  bool requiresStepUp = false;

  Future<void> submitTransfer({
    required int userId,
    required String fromAccountNumber,
    required String toAccountNumber,
    required double amount,
    required String currency,
    required bool stepUpPassed,
  }) async {
    loading = true;
    message = null;
    requiresStepUp = false;
    lastRiskResult = null;
    notifyListeners();

    try {
      final fromAccount = await accountRepository.findByNumberForUser(
        userId,
        fromAccountNumber,
      );

      if (fromAccount == null) {
        message = 'Source account not found';
        return;
      }

      if (fromAccount.balance < amount) {
        message = 'Insufficient balance';
        return;
      }

      final risk = RiskCalculator.evaluate(
        amount: amount,
        currency: currency,
        deviceTrust: 70,
        isNewPayee: true,
      );

      lastRiskResult = risk;

      if (risk.decision == RiskDecision.deny) {
        await riskRepository.create(
          RiskEventModel(
            userId: userId,
            transactionId: null,
            score: risk.score,
            band: risk.band,
            decision: 'DENY',
            details: jsonEncode(risk.reasons),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        message = 'Transfer denied due to high risk';
        return;
      }

      if (risk.decision == RiskDecision.stepUp && !stepUpPassed) {
        await riskRepository.create(
          RiskEventModel(
            userId: userId,
            transactionId: null,
            score: risk.score,
            band: risk.band,
            decision: 'STEP_UP',
            details: jsonEncode(risk.reasons),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        requiresStepUp = true;
        message = 'Step-up confirmation required';
        return;
      }

      final transactionId = await transactionRepository.create(
        TransactionModel(
          userId: userId,
          fromAccountId: fromAccount.id!,
          toAccountNumber: toAccountNumber,
          amount: amount,
          currency: currency,
          status: 'COMPLETED',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      await accountRepository.updateBalance(
        fromAccount.id!,
        fromAccount.balance - amount,
      );

      await riskRepository.create(
        RiskEventModel(
          userId: userId,
          transactionId: transactionId,
          score: risk.score,
          band: risk.band,
          decision: 'ALLOW',
          details: jsonEncode(risk.reasons),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      message = 'Transfer completed successfully';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
