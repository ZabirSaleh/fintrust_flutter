import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/account_model.dart';
import '../../widgets/account_card.dart';
import '../auth/auth_provider.dart';
import '../risk/risk_events_screen.dart';
import '../security/security_center_screen.dart';
import '../transfer/transfer_screen.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthProvider>();
        context.read<DashboardProvider>().loadAccounts(auth.userId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<DashboardProvider>();
    final userId = auth.userId!;
    final accounts = provider.accounts;

    final screens = [
      _DashboardHome(
        accounts: accounts,
        loading: provider.loading,
        error: provider.error,
      ),
      TransferScreen(accounts: accounts, userId: userId),
      RiskEventsScreen(userId: userId),
      SecurityCenterScreen(email: auth.email ?? ''),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FinTrust'),
        actions: [
          IconButton(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Transfer'),
          NavigationDestination(icon: Icon(Icons.security), label: 'Risk'),
          NavigationDestination(icon: Icon(Icons.lock), label: 'Security'),
        ],
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  final List<AccountModel> accounts;
  final bool loading;
  final String? error;

  const _DashboardHome({
    required this.accounts,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final total = accounts.fold<double>(0, (sum, a) => sum + a.balance);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Your money, continuously protected.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Every transfer is evaluated by the local risk engine.'),
          const SizedBox(height: 20),
          AccountCard(
            title: 'Total Holdings',
            value: total.toStringAsFixed(2),
            subtitle: 'Across all wallets',
          ),
          const SizedBox(height: 12),
          if (accounts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No accounts found for this user.'),
              ),
            ),
          ...accounts.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AccountCard(
                title: a.accountNumber,
                value: a.balance.toStringAsFixed(2),
                subtitle: a.currency,
              ),
            ),
          ),
        ],
      ),
    );
  }
}