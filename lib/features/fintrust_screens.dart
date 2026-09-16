import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../services/fintrust_backend.dart';
import '../services/fintrust_controller.dart';
import '../widgets/fintrust_theme.dart';

enum _AuthMode { login, register, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _loginOtpController = TextEditingController();
  final _resetEmailController = TextEditingController();

  final _fullNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _emailOtpController = TextEditingController();
  final _authenticatorController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  String _idType = 'Passport';
  bool _hideLoginPassword = true;
  bool _hideRegisterPassword = true;
  bool _showSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    for (final controller in [
      _loginEmailController,
      _loginPasswordController,
      _loginOtpController,
      _resetEmailController,
      _fullNameController,
      _registerEmailController,
      _phoneController,
      _idNumberController,
      _registerPasswordController,
      _emailOtpController,
      _authenticatorController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);

    if (_showSplash) {
      return const _SplashScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
              children: [
                _AuthHeader(modeLabel: controller.backendModeLabel),
                const SizedBox(height: 26),
                _AuthTabs(
                  mode: _mode,
                  onChanged: (mode) {
                    setState(() => _mode = mode);
                    controller.clearMessages();
                  },
                ),
                const SizedBox(height: 18),
                if (controller.errorMessage != null) ...[
                  _MessageBar(message: controller.errorMessage!, isError: true),
                  const SizedBox(height: 12),
                ],
                if (controller.successMessage != null) ...[
                  _MessageBar(message: controller.successMessage!),
                  const SizedBox(height: 12),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (_mode) {
                    _AuthMode.login => _LoginForm(
                      key: const ValueKey('login'),
                      formKey: _loginFormKey,
                      emailController: _loginEmailController,
                      passwordController: _loginPasswordController,
                      otpController: _loginOtpController,
                      hidePassword: _hideLoginPassword,
                      onTogglePassword: () {
                        setState(
                          () => _hideLoginPassword = !_hideLoginPassword,
                        );
                      },
                      onRequestOtp: () => unawaited(
                        controller.requestLoginOtp(
                          _loginEmailController.text.trim(),
                        ),
                      ),
                      onReset: () {
                        setState(() => _mode = _AuthMode.reset);
                        controller.clearMessages();
                      },
                      onSubmit: () => _submitLogin(controller),
                    ),
                    _AuthMode.register => _RegisterForm(
                      key: const ValueKey('register'),
                      formKey: _registerFormKey,
                      fullNameController: _fullNameController,
                      emailController: _registerEmailController,
                      phoneController: _phoneController,
                      idNumberController: _idNumberController,
                      passwordController: _registerPasswordController,
                      emailOtpController: _emailOtpController,
                      authenticatorController: _authenticatorController,
                      idType: _idType,
                      hidePassword: _hideRegisterPassword,
                      onIdTypeChanged: (value) {
                        if (value != null) {
                          setState(() => _idType = value);
                        }
                      },
                      onTogglePassword: () {
                        setState(
                          () => _hideRegisterPassword = !_hideRegisterPassword,
                        );
                      },
                      onSubmit: () => _submitRegistration(controller),
                    ),
                    _AuthMode.reset => _ResetForm(
                      key: const ValueKey('reset'),
                      formKey: _resetFormKey,
                      emailController: _resetEmailController,
                      onSubmit: () => _submitReset(controller),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitLogin(FintrustController controller) async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await controller.login(
      email: _loginEmailController.text.trim(),
      password: _loginPasswordController.text,
      oneTimeCode: _loginOtpController.text.trim(),
    );
  }

  Future<void> _submitRegistration(FintrustController controller) async {
    if (!(_registerFormKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await controller.register(
      RegistrationPayload(
        fullName: _fullNameController.text.trim(),
        email: _registerEmailController.text.trim(),
        phone: _phoneController.text.trim(),
        idType: _idType,
        idNumber: _idNumberController.text.trim(),
        password: _registerPasswordController.text,
        emailOtp: _emailOtpController.text.trim(),
        authenticatorCode: _authenticatorController.text.trim(),
      ),
    );
  }

  Future<void> _submitReset(FintrustController controller) async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await controller.requestPasswordReset(_resetEmailController.text.trim());
  }
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);
    final screen = switch (controller.selectedIndex) {
      0 => const _HomeScreen(),
      1 => const _TransactionsScreen(),
      2 => const _QrPayScreen(),
      3 => const _ActivityScreen(),
      _ => const _ProfileScreen(),
    };

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey(controller.selectedIndex),
          child: screen,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.selectedIndex,
        onDestinationSelected: controller.selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            selectedIcon: Icon(Icons.swap_horiz_rounded),
            label: 'Money',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);
    final session = controller.session!;
    final profile = session.profile;

    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(profile: profile),
          const SizedBox(height: 18),
          _BalanceCard(session: session),
          const SizedBox(height: 18),
          _ActionRow(
            actions: [
              _ActionItem(
                icon: Icons.add_rounded,
                label: 'Deposit',
                onTap: () => _showDepositSheet(context),
              ),
              _ActionItem(
                icon: Icons.call_made_rounded,
                label: 'Send',
                onTap: () => _showSendSheet(context),
              ),
              _ActionItem(
                icon: Icons.call_received_rounded,
                label: 'Receive',
                onTap: () => _showReceiveSheet(context),
              ),
              _ActionItem(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: () => controller.selectTab(2),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _InsightCard(session: session),
          const SizedBox(height: 14),
          _ActionRow(
            actions: [
              _ActionItem(
                icon: Icons.support_agent_rounded,
                label: 'Support',
                onTap: () => _showSupportSheet(context),
              ),
              _ActionItem(
                icon: Icons.insights_rounded,
                label: 'AI Tips',
                onTap: () => _showAiInsightSheet(context),
              ),
              _ActionItem(
                icon: Icons.bar_chart_rounded,
                label: 'Charts',
                onTap: () => _showDataDashboardSheet(context),
              ),
              _ActionItem(
                icon: Icons.my_location_rounded,
                label: 'GPS',
                onTap: () => _showLocationSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Accounts',
            actionLabel: 'See all',
            onAction: () => controller.selectTab(1),
          ),
          const SizedBox(height: 10),
          _ListCard(
            children: [
              _AccountRow(
                icon: Icons.account_balance_wallet_rounded,
                color: FintrustColors.blue,
                name: 'Checking Account',
                number: profile.accountNumber,
                amount: '${session.currency} ${_formatAmount(session.balance)}',
              ),
              const _AccountRow(
                icon: Icons.savings_rounded,
                color: Color(0xFF27C79A),
                name: 'Savings Account',
                number: '**** 8888',
                amount: 'MYR 8,200.25',
              ),
              const _AccountRow(
                icon: Icons.trending_up_rounded,
                color: Color(0xFF1D9AC5),
                name: 'Investment Account',
                number: '**** 1010',
                amount: 'MYR 4,200.00',
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Recent Transactions',
            actionLabel: 'See all',
            onAction: () => controller.selectTab(1),
          ),
          const SizedBox(height: 10),
          _ListCard(
            children: session.transactions
                .take(1)
                .map((transaction) => _TransactionRow(transaction: transaction))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TransactionsScreen extends StatefulWidget {
  const _TransactionsScreen();

  @override
  State<_TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<_TransactionsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final session = FintrustScope.watch(context).session!;
    final transactions = session.transactions.where((transaction) {
      return _filter == 'All' || transaction.direction == _filter;
    }).toList();

    return _PageScaffold(
      title: 'Money',
      subtitle: 'All movement in one place',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FinanceDashboard(session: session),
          const SizedBox(height: 18),
          _ReportsPanel(session: session),
          const SizedBox(height: 18),
          _TinyFilter(
            value: _filter,
            values: const ['All', 'Incoming', 'Outgoing'],
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 18),
          _ListCard(
            children: transactions
                .map((transaction) => _TransactionRow(transaction: transaction))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _QrPayScreen extends StatefulWidget {
  const _QrPayScreen();

  @override
  State<_QrPayScreen> createState() => _QrPayScreenState();
}

class _QrPayScreenState extends State<_QrPayScreen> {
  String? _lastCode;
  DateTime? _lastScanAt;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Scan',
      subtitle: 'QR payments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 420,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    fit: BoxFit.cover,
                    tapToFocus: true,
                    onDetect: _handleDetection,
                    placeholderBuilder: (_) => const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    errorBuilder: (_, error) => ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            error.errorCode.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _ScanFrame(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SimpleCard(
            child: Row(
              children: [
                const _SoftIcon(icon: Icons.qr_code_2_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _lastCode ?? 'Point your camera at a FINTRUST QR code.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleDetection(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) {
      return;
    }

    final barcode = capture.barcodes.first;
    final code = barcode.rawValue ?? barcode.displayValue;
    if (code == null || code.trim().isEmpty) {
      return;
    }

    final now = DateTime.now();
    final duplicate =
        _lastCode == code &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(seconds: 3);
    if (duplicate) {
      return;
    }

    final trimmedCode = code.trim();
    final payment = _QrPaymentPayload.tryParse(trimmedCode);

    setState(() {
      _lastCode = trimmedCode;
      _lastScanAt = now;
    });

    if (payment == null) {
      unawaited(FintrustScope.read(context).recordQrScan(trimmedCode));
      return;
    }

    unawaited(_showQrPaymentConfirmation(context, payment));
  }
}

class _ActivityScreen extends StatelessWidget {
  const _ActivityScreen();

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);
    final activity = controller.session!.activity;

    return _PageScaffold(
      title: 'Activity',
      subtitle: 'Alerts, security, and account updates',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Push alerts',
            actionLabel: controller.pushToken == null ? 'Preview' : 'Enabled',
            onAction: () {},
          ),
          const SizedBox(height: 10),
          _ListCard(
            children: controller.alerts
                .map((alert) => _NotificationRow(alert: alert))
                .toList(),
          ),
          const SizedBox(height: 22),
          Text(
            'Account activity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _ListCard(
            children: activity
                .map((event) => _ActivityRow(event: event))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deviceController = TextEditingController();
  String? _loadedProfileId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = FintrustScope.watch(context).session!.profile;
    if (_loadedProfileId != profile.id) {
      _loadedProfileId = profile.id;
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _deviceController.text = profile.trustedDeviceName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);
    final profile = controller.session!.profile;

    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                _Avatar(name: profile.fullName, size: 86),
                const SizedBox(height: 14),
                Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(profile.email, textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _ListCard(
            children: [
              _InfoRow(
                icon: Icons.shield_outlined,
                title: 'Trust score',
                value: '${profile.riskScore}%',
              ),
              _InfoRow(
                icon: Icons.credit_card_rounded,
                title: profile.idType,
                value: profile.maskedIdNumber,
              ),
              _InfoRow(
                icon: Icons.public_rounded,
                title: 'Region',
                value: profile.country,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SimpleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App security',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark mode'),
                  subtitle: const Text('Black themed FINTRUST interface'),
                  value: controller.isDarkMode,
                  onChanged: controller.toggleDarkMode,
                ),
                const Divider(height: 22, color: FintrustColors.border),
                _InfoRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push alerts',
                  value: controller.pushToken == null ? 'Preview' : 'Enabled',
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'GPS security',
                  value: controller.lastLocation == null ? 'Not set' : 'Active',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: _SimpleCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deviceController,
                    decoration: const InputDecoration(
                      labelText: 'Trusted device',
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => _saveProfile(controller),
                    child: controller.isBusy
                        ? const _ButtonSpinner()
                        : const Text('Save changes'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: controller.isBusy ? null : controller.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile(FintrustController controller) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await controller.updateProfile(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      trustedDeviceName: _deviceController.text.trim(),
    );
  }
}

enum _MoneyActionMode { deposit, send }

Future<void> _showDepositSheet(BuildContext context) {
  FintrustScope.read(context).clearMessages();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _MoneyActionSheet(mode: _MoneyActionMode.deposit),
  );
}

Future<void> _showSendSheet(BuildContext context) {
  FintrustScope.read(context).clearMessages();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _MoneyActionSheet(mode: _MoneyActionMode.send),
  );
}

Future<void> _showReceiveSheet(BuildContext context) {
  FintrustScope.read(context).clearMessages();
  final controller = FintrustScope.read(context);
  final profile = controller.session!.profile;
  final payload = controller.receiveQrPayload();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Receive money',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Share this FINTRUST A/C number with the sender.'),
            const SizedBox(height: 18),
            _SimpleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your A/C No.'),
                  const SizedBox(height: 8),
                  SelectableText(
                    profile.accountNumber,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(child: _QrCodeBox(data: payload, size: 188)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: profile.accountNumber),
                );
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('A/C number copied')),
                  );
                  Navigator.pop(sheetContext);
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy A/C number'),
            ),
          ],
        ),
      );
    },
  );
}

class _MoneyActionSheet extends StatefulWidget {
  const _MoneyActionSheet({required this.mode});

  final _MoneyActionMode mode;

  @override
  State<_MoneyActionSheet> createState() => _MoneyActionSheetState();
}

class _MoneyActionSheetState extends State<_MoneyActionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);
    final isSend = widget.mode == _MoneyActionMode.send;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        8,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isSend ? 'Send to A/C' : 'Deposit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isSend
                  ? 'Enter the recipient FINTRUST A/C number.'
                  : 'Add money into your own FINTRUST A/C.',
            ),
            const SizedBox(height: 18),
            if (isSend) ...[
              TextFormField(
                controller: _accountController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Recipient A/C No.',
                  hintText: 'FT-XXXX-XXXXXX',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter recipient A/C number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],
            if (controller.errorMessage != null) ...[
              _MessageBar(message: controller.errorMessage!, isError: true),
              const SizedBox(height: 12),
            ],
            if (controller.successMessage != null) ...[
              _MessageBar(message: controller.successMessage!),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () => unawaited(controller.requestTransactionOtp()),
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: Text(
                controller.transactionOtpChallengeId == null
                    ? 'Send transaction email OTP'
                    : 'Transaction email OTP sent',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: _sixDigitFormatters,
              decoration: const InputDecoration(
                labelText: 'Email transaction OTP',
              ),
              validator: _sixDigitValidator,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: controller.isBusy ? null : _submit,
              child: controller.isBusy
                  ? const _ButtonSpinner()
                  : Text(isSend ? 'Send money' : 'Deposit now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final controller = FintrustScope.read(context);
    final amount = double.parse(_amountController.text.trim());
    final isSend = widget.mode == _MoneyActionMode.send;
    final success = isSend
        ? await controller.sendToAccount(
            accountNumber: _accountController.text.trim(),
            amount: amount,
            otp: _otpController.text.trim(),
          )
        : await controller.depositToOwnAccount(
            amount,
            otp: _otpController.text.trim(),
          );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}

Future<void> _showSupportSheet(BuildContext context) {
  final messageController = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          8,
          22,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 28,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final controller = FintrustScope.watch(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Support Admin',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: ListView(
                    children: controller.supportMessages
                        .map((message) => _ChatBubble(message: message))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message support',
                    suffixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    controller.sendSupportMessage(messageController.text);
                    messageController.clear();
                    setSheetState(() {});
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send secure message'),
                ),
              ],
            );
          },
        ),
      );
    },
  ).whenComplete(messageController.dispose);
}

Future<void> _showAiInsightSheet(BuildContext context) {
  final controller = FintrustScope.read(context);
  return _showFeatureSheet(
    context,
    title: 'AI recommendation',
    icon: Icons.auto_awesome_rounded,
    child: Text(controller.aiRecommendation),
  );
}

Future<void> _showDataDashboardSheet(BuildContext context) {
  final session = FintrustScope.read(context).session!;
  return _showFeatureSheet(
    context,
    title: 'Expense and earning',
    icon: Icons.bar_chart_rounded,
    child: _FinanceDashboard(session: session),
  );
}

Future<void> _showLocationSheet(BuildContext context) {
  final controller = FintrustScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final location = controller.lastLocation;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'GPS security',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verify your location for risk checks and account protection.',
                ),
                const SizedBox(height: 16),
                _SimpleCard(
                  child: Text(
                    location == null
                        ? 'No GPS signal captured yet.'
                        : 'Lat ${location.latitude.toStringAsFixed(5)}, Lng ${location.longitude.toStringAsFixed(5)}',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: controller.captureCurrentLocation,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Verify current location'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

Future<void> _showFeatureSheet(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _SoftIcon(icon: icon),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
    },
  );
}

Future<void> _showQrPaymentConfirmation(
  BuildContext context,
  _QrPaymentPayload payment,
) {
  final otpController = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final controller = FintrustScope.watch(sheetContext);
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm QR payment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Send money to ${payment.accountNumber}.'),
            const SizedBox(height: 16),
            _SimpleCard(
              child: Text(
                '${controller.session!.currency} ${payment.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () => unawaited(controller.requestTransactionOtp()),
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: Text(
                controller.transactionOtpChallengeId == null
                    ? 'Send QR payment email OTP'
                    : 'QR payment email OTP sent',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: otpController,
              keyboardType: TextInputType.number,
              inputFormatters: _sixDigitFormatters,
              decoration: const InputDecoration(
                labelText: 'Email transaction OTP',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () async {
                      final success = await controller.payQrAccount(
                        accountNumber: payment.accountNumber,
                        amount: payment.amount,
                        otp: otpController.text.trim(),
                      );
                      if (success && sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    },
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Pay securely'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(otpController.dispose);
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.modeLabel});

  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MockStatusBar(),
        const SizedBox(height: 58),
        const _BrandMark(size: 34),
        const SizedBox(height: 32),
        _SmallPill(icon: Icons.cloud_done_outlined, label: modeLabel),
      ],
    );
  }
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_AuthMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: _AuthMode.login, label: Text('Login')),
        ButtonSegment(value: _AuthMode.register, label: Text('Register')),
        ButtonSegment(value: _AuthMode.reset, label: Text('Reset')),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.otpController,
    required this.hidePassword,
    required this.onTogglePassword,
    required this.onRequestOtp,
    required this.onReset,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController otpController;
  final bool hidePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onRequestOtp;
  final VoidCallback onReset;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text('Sign in to continue to your account'),
          const SizedBox(height: 34),
          TextFormField(
            key: const Key('login_email'),
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@email.com',
            ),
            validator: _emailValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('login_password'),
            controller: passwordController,
            obscureText: hidePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: hidePassword ? 'Show password' : 'Hide password',
                onPressed: onTogglePassword,
                icon: Icon(
                  hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: _passwordValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('login_otp'),
            controller: otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: _sixDigitFormatters,
            decoration: const InputDecoration(labelText: 'Email OTP'),
            validator: _sixDigitValidator,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.isBusy ? null : onRequestOtp,
            icon: const Icon(Icons.sms_outlined),
            label: Text(
              controller.loginOtpChallengeId == null
                  ? 'Send login email OTP'
                  : 'Login email OTP sent',
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const Key('login_button'),
            onPressed: controller.isBusy ? null : onSubmit,
            child: controller.isBusy
                ? const _ButtonSpinner()
                : const Text('Continue'),
          ),
          const SizedBox(height: 24),
          const _OrDivider(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: controller.isBusy ? null : onSubmit,
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Sign in with Biometrics'),
          ),
          const SizedBox(height: 20),
          TextButton(onPressed: onReset, child: const Text('Forgot password')),
          const SizedBox(height: 18),
          const Text(
            'By continuing, you agree to our\nTerms of Service and Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: FintrustColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.fullNameController,
    required this.emailController,
    required this.phoneController,
    required this.idNumberController,
    required this.passwordController,
    required this.emailOtpController,
    required this.authenticatorController,
    required this.idType,
    required this.hidePassword,
    required this.onIdTypeChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController idNumberController;
  final TextEditingController passwordController;
  final TextEditingController emailOtpController;
  final TextEditingController authenticatorController;
  final String idType;
  final bool hidePassword;
  final ValueChanged<String?> onIdTypeChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);

    return Form(
      key: formKey,
      child: _SimpleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: fullNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: _emailValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (value) {
                if ((value ?? '').trim().length < 8) {
                  return 'Enter a valid phone number.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: idType,
              decoration: const InputDecoration(labelText: 'ID type'),
              items: const [
                DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                DropdownMenuItem(
                  value: 'Driving license',
                  child: Text('Driving license'),
                ),
                DropdownMenuItem(
                  value: 'National ID',
                  child: Text('National ID'),
                ),
              ],
              onChanged: onIdTypeChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: idNumberController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'ID number'),
              validator: (value) {
                if ((value ?? '').trim().length < 4) {
                  return 'Enter the ID number.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              obscureText: hidePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: hidePassword ? 'Show password' : 'Hide password',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: _passwordValidator,
            ),
            const SizedBox(height: 18),
            Text(
              'Verification',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: emailOtpController,
              keyboardType: TextInputType.number,
              inputFormatters: _sixDigitFormatters,
              decoration: const InputDecoration(labelText: 'Email code'),
              validator: _sixDigitValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: authenticatorController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: _sixDigitFormatters,
              decoration: const InputDecoration(
                labelText: 'Authenticator code',
              ),
              validator: _sixDigitValidator,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: controller.isBusy ? null : onSubmit,
              child: controller.isBusy
                  ? const _ButtonSpinner()
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetForm extends StatelessWidget {
  const _ResetForm({
    required this.formKey,
    required this.emailController,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);

    return Form(
      key: formKey,
      child: _SimpleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reset password',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('We will send a secure reset link to your email.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: _emailValidator,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: controller.isBusy ? null : onSubmit,
              child: controller.isBusy
                  ? const _ButtonSpinner()
                  : const Text('Send reset link'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.child, this.title, this.subtitle});

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!),
            ],
            const SizedBox(height: 24),
          ],
          child,
        ],
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06156F), Color(0xFF000A3A)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _BlueWaveBackdrop()),
            SafeArea(
              child: Column(
                children: [
                  const _MockStatusBar(light: true),
                  const Spacer(),
                  const _BrandMark(size: 92),
                  const SizedBox(height: 24),
                  const Text(
                    'FinTrust',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Secure',
                    style: TextStyle(
                      color: Color(0xFF16B8FF),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Zero Trust. Total Protection.',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    width: 116,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0FB8FF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${profile.fullName.split(' ').first} 👋',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              const Text('Secure today, peace of mind tomorrow.'),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => FintrustScope.read(context).selectTab(3),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.session});

  final BackendSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 182,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1167F5), Color(0xFF061E91)],
        ),
        boxShadow: [
          BoxShadow(
            color: FintrustColors.blue.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _BalanceWave()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                '\$${_formatAmount(session.balance)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24C486),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      '+ 4.35%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'from last month',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    session.profile.accountNumber,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  const Text(
                    'VISA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.color,
    required this.name,
    required this.number,
    required this.amount,
  });

  final IconData icon;
  final Color color;
  final String name;
  final String number;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _SoftIcon(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(number),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: FintrustColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.actions});

  final List<_ActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(child: _ActionButton(item: actions[i])),
          if (i != actions.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.item});

  final _ActionItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        height: 78,
        decoration: BoxDecoration(
          color: FintrustColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FintrustColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 23),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FintrustColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FintrustColors.border),
      ),
      child: child,
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const _SimpleCard(child: Text('Nothing here yet.'));
    }

    return Container(
      decoration: BoxDecoration(
        color: FintrustColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FintrustColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: FintrustColors.border),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.session});

  final BackendSession session;

  @override
  Widget build(BuildContext context) {
    final controller = FintrustScope.watch(context);
    return _SimpleCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SoftIcon(icon: Icons.auto_awesome_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI weekly insight',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(controller.aiRecommendation),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceDashboard extends StatelessWidget {
  const _FinanceDashboard({required this.session});

  final BackendSession session;

  @override
  Widget build(BuildContext context) {
    final income = session.transactions
        .where((transaction) => transaction.amount > 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final expense = session.transactions
        .where((transaction) => transaction.amount < 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());

    return _SimpleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expense vs earning',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: CustomPaint(
              painter: _FinanceChartPainter(income: income, expense: expense),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Earning',
                  value: '${session.currency} ${_formatAmount(income)}',
                  color: const Color(0xFF1E7E52),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Expense',
                  value: '${session.currency} ${_formatAmount(expense)}',
                  color: FintrustColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel({required this.session});

  final BackendSession session;

  @override
  Widget build(BuildContext context) {
    final activity = session.activity;
    final transactions = session.transactions;
    final incomingCount = transactions
        .where((transaction) => transaction.amount > 0)
        .length;
    final outgoingCount = transactions
        .where((transaction) => transaction.amount < 0)
        .length;

    return _SimpleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SoftIcon(icon: Icons.summarize_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reports',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReportStat(
                label: 'Transactions',
                value: '${transactions.length}',
                icon: Icons.receipt_long_rounded,
              ),
              _ReportStat(
                label: 'Incoming',
                value: '$incomingCount',
                icon: Icons.call_received_rounded,
              ),
              _ReportStat(
                label: 'Outgoing',
                value: '$outgoingCount',
                icon: Icons.call_made_rounded,
              ),
              _ReportStat(
                label: 'Activity',
                value: '${activity.length}',
                icon: Icons.timeline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'User activity report',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _MiniReportRow(
            label: 'Latest activity',
            value: activity.isEmpty ? 'None' : activity.first.title,
          ),
          _MiniReportRow(
            label: 'Last transaction',
            value: transactions.isEmpty ? 'None' : transactions.first.title,
          ),
          _MiniReportRow(
            label: 'Current balance',
            value: '${session.currency} ${_formatAmount(session.balance)}',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportCsv(context, session),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('CSV'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _exportPdf(context, session),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FintrustColors.softBlue.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FintrustColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: FintrustColors.blue),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniReportRow extends StatelessWidget {
  const _MiniReportRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isAdmin
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final color = message.isAdmin
        ? Theme.of(context).colorScheme.surface
        : FintrustColors.blue;
    final textColor = message.isAdmin
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FintrustColors.border),
        ),
        child: Text(message.text, style: TextStyle(color: textColor)),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.alert});

  final NotificationAlert alert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SoftIcon(icon: Icons.notifications_active_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(alert.body),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_relativeDate(alert.createdAt)),
        ],
      ),
    );
  }
}

class _QrCodeBox extends StatelessWidget {
  const _QrCodeBox({required this.data, required this.size});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FintrustColors.border),
      ),
      child: QrImageView(
        data: data,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: FintrustColors.ink,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: FintrustColors.ink,
        ),
      ),
    );
  }
}

class _QrPaymentPayload {
  const _QrPaymentPayload({required this.accountNumber, required this.amount});

  final String accountNumber;
  final double amount;

  static _QrPaymentPayload? tryParse(String value) {
    if (!value.startsWith('FINTRUST|')) {
      return null;
    }

    final parts = value.split('|').skip(1);
    String? account;
    double? amount;
    for (final part in parts) {
      final pieces = part.split('=');
      if (pieces.length != 2) {
        continue;
      }
      if (pieces.first == 'account') {
        account = pieces.last;
      }
      if (pieces.first == 'amount') {
        amount = double.tryParse(pieces.last);
      }
    }
    if (account == null || amount == null || amount <= 0) {
      return null;
    }
    return _QrPaymentPayload(accountNumber: account, amount: amount);
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final FinTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final incoming = transaction.amount >= 0;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _SoftIcon(
            icon: incoming
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.counterparty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transaction.chainStatus.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        transaction.chainStatus == 'anchored'
                            ? Icons.verified_rounded
                            : Icons.info_outline_rounded,
                        size: 14,
                        color: transaction.chainStatus == 'anchored'
                            ? const Color(0xFF1E7E52)
                            : FintrustColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          transaction.chainStatus == 'anchored'
                              ? 'Anchored on Sepolia'
                              : 'Blockchain ${transaction.chainStatus}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatSignedMoney(transaction.amount, transaction.currency),
                style: TextStyle(
                  color: incoming
                      ? const Color(0xFF1E7E52)
                      : FintrustColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(_relativeDate(transaction.occurredAt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event});

  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SoftIcon(icon: _activityIcon(event.iconKey)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(event.subtitle),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_relativeDate(event.occurredAt)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _SoftIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            value,
            style: const TextStyle(
              color: FintrustColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyFilter extends StatelessWidget {
  const _TinyFilter({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final item in values)
          ChoiceChip(
            label: Text(item),
            selected: item == value,
            onSelected: (_) => onChanged(item),
          ),
      ],
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FintrustColors.profileAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C62F6), Color(0xFF000A4C)],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C62F6).withValues(alpha: 0.22),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.13),
          ),
        ],
      ),
      child: CustomPaint(painter: _FinTrustLogoPainter()),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, this.color = FintrustColors.blue});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FintrustColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FintrustColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: FintrustColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('or', style: TextStyle(color: FintrustColors.muted)),
        ),
        Expanded(child: Divider(color: FintrustColors.border)),
      ],
    );
  }
}

class _MessageBar extends StatelessWidget {
  const _MessageBar({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFE8EA) : const Color(0xFFE9F8EF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? FintrustColors.danger : FintrustColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MockStatusBar extends StatelessWidget {
  const _MockStatusBar({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : FintrustColors.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      child: Row(
        children: [
          Text(
            '9:41',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Icon(Icons.signal_cellular_alt_rounded, color: color, size: 15),
          const SizedBox(width: 4),
          Icon(Icons.wifi_rounded, color: color, size: 15),
          const SizedBox(width: 4),
          Icon(Icons.battery_full_rounded, color: color, size: 17),
        ],
      ),
    );
  }
}

class _FinTrustLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final whitePaint = Paint()..color = Colors.white;
    final bluePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4DE5FF), Color(0xFF0D73FF)],
      ).createShader(Offset.zero & size);

    final shield = Path()
      ..moveTo(size.width * 0.29, size.height * 0.23)
      ..quadraticBezierTo(
        size.width * 0.29,
        size.height * 0.18,
        size.width * 0.36,
        size.height * 0.18,
      )
      ..lineTo(size.width * 0.73, size.height * 0.18)
      ..lineTo(size.width * 0.73, size.height * 0.36)
      ..lineTo(size.width * 0.48, size.height * 0.36)
      ..lineTo(size.width * 0.48, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.66,
        size.width * 0.33,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.29,
        size.height * 0.50,
        size.width * 0.29,
        size.height * 0.39,
      )
      ..close();
    canvas.drawPath(shield, whitePaint);

    final fold = Path()
      ..moveTo(size.width * 0.48, size.height * 0.46)
      ..lineTo(size.width * 0.73, size.height * 0.46)
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.58,
        size.width * 0.53,
        size.height * 0.72,
      )
      ..lineTo(size.width * 0.48, size.height * 0.76)
      ..close();
    canvas.drawPath(fold, bluePaint);

    final bar = Path()
      ..moveTo(size.width * 0.43, size.height * 0.40)
      ..lineTo(size.width * 0.70, size.height * 0.40)
      ..lineTo(size.width * 0.62, size.height * 0.50)
      ..lineTo(size.width * 0.43, size.height * 0.50)
      ..close();
    canvas.drawPath(bar, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlueWaveBackdrop extends StatelessWidget {
  const _BlueWaveBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BlueWavePainter());
  }
}

class _BlueWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 11; i++) {
      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFF0AB8FF),
          const Color(0xFF145CFF),
          i / 10,
        )!.withValues(alpha: 0.30 - (i * 0.017))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final y = size.height * (0.62 + i * 0.017);
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * 0.28,
          y - 80,
          size.width * 0.58,
          y + 95,
          size.width,
          y - 18,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BalanceWave extends StatelessWidget {
  const _BalanceWave();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BalanceWavePainter());
  }
}

class _BalanceWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22C7FF).withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..moveTo(size.width * 0.34, size.height * 0.71)
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.75,
        size.width * 0.52,
        size.height * 0.60,
        size.width * 0.61,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.56,
        size.width * 0.68,
        size.height * 0.38,
        size.width * 0.76,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.83,
        size.height * 0.46,
        size.width * 0.81,
        size.height * 0.23,
        size.width * 0.89,
        size.height * 0.32,
      )
      ..cubicTo(
        size.width * 0.95,
        size.height * 0.39,
        size.width * 0.96,
        size.height * 0.25,
        size.width,
        size.height * 0.21,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FinanceChartPainter extends CustomPainter {
  const _FinanceChartPainter({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = FintrustColors.border
      ..strokeWidth = 1;
    final incomePaint = Paint()..color = const Color(0xFF1E7E52);
    final expensePaint = Paint()..color = FintrustColors.danger;
    final maxValue = math.max(1, math.max(income, expense));
    final barWidth = size.width * 0.22;
    final baseline = size.height - 10;
    final maxHeight = size.height - 24;

    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      axisPaint,
    );

    void drawBar(double x, double value, Paint paint) {
      final height = (value / maxValue) * maxHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseline - height, barWidth, height),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, paint);
    }

    drawBar(size.width * 0.22, income, incomePaint);
    drawBar(size.width * 0.56, expense, expensePaint);
  }

  @override
  bool shouldRepaint(covariant _FinanceChartPainter oldDelegate) {
    return oldDelegate.income != income || oldDelegate.expense != expense;
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

final _sixDigitFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(6),
];

String? _requiredValidator(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return 'This field is required.';
  }
  return null;
}

String? _emailValidator(String? value) {
  final trimmed = (value ?? '').trim();
  final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  if (!isValid) {
    return 'Enter a valid email.';
  }
  return null;
}

String? _passwordValidator(String? value) {
  if ((value ?? '').length < 8) {
    return 'Use at least 8 characters.';
  }
  return null;
}

String? _sixDigitValidator(String? value) {
  if (!RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())) {
    return 'Enter 6 digits.';
  }
  return null;
}

IconData _activityIcon(String key) {
  return switch (key) {
    'shield' => Icons.shield_outlined,
    'search' => Icons.manage_search_rounded,
    'badge' => Icons.verified_user_outlined,
    'scan' => Icons.qr_code_scanner_rounded,
    'deposit' => Icons.add_card_rounded,
    'transfer' => Icons.sync_alt_rounded,
    _ => Icons.history_rounded,
  };
}

String _formatAmount(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    final fromEnd = whole.length - i;
    buffer.write(whole[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }

  return '${buffer.toString()}.${parts.last}';
}

String _formatSignedMoney(double amount, String currency) {
  final prefix = amount >= 0 ? '+' : '-';
  return '$prefix $currency ${_formatAmount(amount.abs())}';
}

Future<void> _exportCsv(BuildContext context, BackendSession session) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}fintrust_transaction_report.csv',
    );
    await file.writeAsString(_buildCsvReport(session));

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV report saved: ${file.path}')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $error')));
    }
  }
}

Future<void> _exportPdf(BuildContext context, BackendSession session) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}fintrust_summary_report.pdf',
    );
    final income = session.transactions
        .where((transaction) => transaction.amount > 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final expense = session.transactions
        .where((transaction) => transaction.amount < 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('FINTRUST Summary Report')),
          pw.Text('User: ${session.profile.fullName}'),
          pw.Text('Account: ${session.profile.accountNumber}'),
          pw.Text(
            'Balance: ${session.currency} ${_formatAmount(session.balance)}',
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Bullet(
            text: 'Total earning: ${session.currency} ${_formatAmount(income)}',
          ),
          pw.Bullet(
            text:
                'Total expense: ${session.currency} ${_formatAmount(expense)}',
          ),
          pw.Bullet(text: 'Transactions: ${session.transactions.length}'),
          pw.Bullet(text: 'User activity events: ${session.activity.length}'),
          pw.SizedBox(height: 14),
          pw.Text(
            'Booking / Transaction Report',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Title', 'Counterparty', 'Amount', 'Status'],
            data: session.transactions
                .map(
                  (transaction) => [
                    _shortDate(transaction.occurredAt),
                    transaction.title,
                    transaction.counterparty,
                    _formatSignedMoney(
                      transaction.amount,
                      transaction.currency,
                    ),
                    transaction.status,
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'User Activity Report',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...session.activity
              .take(8)
              .map(
                (event) => pw.Bullet(
                  text:
                      '${_shortDate(event.occurredAt)} - ${event.title}: ${event.subtitle}',
                ),
              ),
        ],
      ),
    );

    await file.writeAsBytes(await pdf.save());

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF report saved: ${file.path}')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    }
  }
}

String _buildCsvReport(BackendSession session) {
  final buffer = StringBuffer()
    ..writeln('FINTRUST Transaction Report')
    ..writeln('User,${_csv(session.profile.fullName)}')
    ..writeln('Account,${_csv(session.profile.accountNumber)}')
    ..writeln(
      'Balance,${_csv('${session.currency} ${_formatAmount(session.balance)}')}',
    )
    ..writeln()
    ..writeln('Date,Title,Counterparty,Category,Direction,Amount,Status');

  for (final transaction in session.transactions) {
    buffer.writeln(
      [
        _shortDate(transaction.occurredAt),
        transaction.title,
        transaction.counterparty,
        transaction.category,
        transaction.direction,
        _formatSignedMoney(transaction.amount, transaction.currency),
        transaction.status,
      ].map(_csv).join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('User Activity Report')
    ..writeln('Date,Title,Subtitle');
  for (final event in session.activity) {
    buffer.writeln(
      [
        _shortDate(event.occurredAt),
        event.title,
        event.subtitle,
      ].map(_csv).join(','),
    );
  }

  return buffer.toString();
}

String _csv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _shortDate(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _relativeDate(DateTime value) {
  final delta = DateTime.now().difference(value);
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes.clamp(1, 59)}m';
  }
  if (delta.inHours < 24) {
    return '${delta.inHours}h';
  }
  if (delta.inDays < 7) {
    return '${delta.inDays}d';
  }
  return '${value.day}/${value.month}/${value.year}';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'FT';
  }
  if (parts.length == 1) {
    final first = parts.first;
    return first.length >= 2
        ? first.substring(0, 2).toUpperCase()
        : first.toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
