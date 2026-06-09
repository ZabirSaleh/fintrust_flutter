import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.swap_horiz),
              title: Text('Transfer to ACC12345'),
              subtitle: Text('RM 100.00 • Completed'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.payment),
              title: Text('QR Payment'),
              subtitle: Text('RM 25.00 • Completed'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.account_balance_wallet),
              title: Text('Wallet Top Up'),
              subtitle: Text('RM 50.00 • Pending'),
            ),
          ),
        ],
      ),
    );
  }
}
