import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/session_service.dart';
import 'data/database/app_database.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/risk_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/repositories/user_repository.dart';
import 'features/auth/auth_provider.dart';
import 'features/dashboard/dashboard_provider.dart';
import 'features/risk/risk_provider.dart';
import 'features/transfer/transfer_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  await db.init();

  final sessionService = SessionService();
  final userRepository = UserRepository(db);
  final accountRepository = AccountRepository(db);
  final transactionRepository = TransactionRepository(db);
  final riskRepository = RiskRepository(db);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: db),
        Provider.value(value: sessionService),
        Provider.value(value: userRepository),
        Provider.value(value: accountRepository),
        Provider.value(value: transactionRepository),
        Provider.value(value: riskRepository),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            userRepository: userRepository,
            accountRepository: accountRepository,
            sessionService: sessionService,
          )..restoreSession(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(accountRepository: accountRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => TransferProvider(
            accountRepository: accountRepository,
            transactionRepository: transactionRepository,
            riskRepository: riskRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RiskProvider(riskRepository: riskRepository),
        ),
      ],
      child: const FinTrustApp(),
    ),
  );
}
