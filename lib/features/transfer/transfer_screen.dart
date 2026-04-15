import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/validators.dart';
import '../../data/models/account_model.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/info_card.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/dashboard_provider.dart';
import 'transfer_provider.dart';

class TransferScreen extends StatefulWidget {
  final List<AccountModel> accounts;
  final int userId;

  const TransferScreen({
    super.key,
    required this.accounts,
    required this.userId,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromAccount = TextEditingController();
  final _toAccount = TextEditingController();
  final _amount = TextEditingController(text: '100');
  final _currency = TextEditingController(text: 'MYR');
  bool _stepUpPassed = false;

  @override
  void dispose() {
    _fromAccount.dispose();
    _toAccount.dispose();
    _amount.dispose();
    _currency.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _fromAccount.text = widget.accounts.first.accountNumber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransferProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Risk-aware transfer',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _fromAccount,
                      label: 'From account',
                      validator: (v) => Validators.requiredField(v, 'From account'),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _toAccount,
                      label: 'To account',
                      validator: (v) => Validators.requiredField(v, 'To account'),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _amount,
                      label: 'Amount',
                      keyboardType: TextInputType.number,
                      validator: Validators.amount,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _currency,
                      label: 'Currency',
                      validator: (v) => Validators.requiredField(v, 'Currency'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _stepUpPassed,
                      onChanged: (v) => setState(() => _stepUpPassed = v),
                      title: const Text('Step-up passed'),
                      subtitle: const Text('Simulate successful MFA'),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      text: provider.loading ? 'Processing...' : 'Submit transfer',
                      onPressed: provider.loading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              await provider.submitTransfer(
                                userId: widget.userId,
                                fromAccountNumber: _fromAccount.text.trim(),
                                toAccountNumber: _toAccount.text.trim(),
                                amount: double.parse(_amount.text.trim()),
                                currency: _currency.text.trim().toUpperCase(),
                                stepUpPassed: _stepUpPassed,
                              );
                              if (!mounted) return;
                              context.read<DashboardProvider>().loadAccounts(widget.userId);
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (provider.message != null) ...[
            const SizedBox(height: 12),
            InfoCard(
              title: 'Result',
              value: provider.message!,
              subtitle: provider.lastRiskResult == null
                  ? ''
                  : 'Risk: ${provider.lastRiskResult!.band} (${provider.lastRiskResult!.score})',
            ),
          ],
          if (provider.lastRiskResult != null) ...[
            const SizedBox(height: 12),
            InfoCard(
              title: 'Risk reasons',
              value: provider.lastRiskResult!.reasons.join(', '),
              subtitle: 'Decision: ${provider.lastRiskResult!.decision.name.toUpperCase()}',
            ),
          ],
        ],
      ),
    );
  }
}
