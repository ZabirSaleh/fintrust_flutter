import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

import 'fintrust_backend.dart';

class NotificationAlert {
  const NotificationAlert({
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String title;
  final String body;
  final DateTime createdAt;
}

class SupportMessage {
  const SupportMessage({
    required this.text,
    required this.createdAt,
    required this.isAdmin,
  });

  final String text;
  final DateTime createdAt;
  final bool isAdmin;
}

class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime capturedAt;
}

class FintrustController extends ChangeNotifier {
  FintrustController(this.backend);

  final FintrustBackend backend;

  BackendSession? _session;
  bool _isInitializing = true;
  bool _isBusy = false;
  String? _errorMessage;
  String? _successMessage;
  int _selectedIndex = 0;
  bool _isDarkMode = false;
  String? _pushToken;
  LocationSnapshot? _lastLocation;
  String? _loginOtpChallengeId;
  String? _transactionOtpChallengeId;
  String _loginOtpPreview = '';
  String _transactionOtpPreview = '';
  final List<NotificationAlert> _alerts = [];
  final List<SupportMessage> _supportMessages = [
    SupportMessage(
      text: 'Hi, FINTRUST Support here. How can we help today?',
      createdAt: DateTime(2026, 1, 1, 9),
      isAdmin: true,
    ),
  ];

  BackendSession? get session => _session;

  bool get isSignedIn => _session != null;

  bool get isInitializing => _isInitializing;

  bool get isBusy => _isBusy;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  int get selectedIndex => _selectedIndex;

  String get backendModeLabel => backend.modeLabel;

  bool get isFirebaseBacked => backend.isFirebaseBacked;

  bool get isDarkMode => _isDarkMode;

  String? get pushToken => _pushToken;

  LocationSnapshot? get lastLocation => _lastLocation;

  String? get loginOtpChallengeId => _loginOtpChallengeId;

  String? get transactionOtpChallengeId => _transactionOtpChallengeId;

  List<NotificationAlert> get alerts => List.unmodifiable(_alerts);

  List<SupportMessage> get supportMessages =>
      List.unmodifiable(_supportMessages);

  String get aiRecommendation {
    final current = _session;
    if (current == null) {
      return 'Sign in to receive weekly and monthly spending guidance.';
    }

    final outgoing = current.transactions
        .where((transaction) => transaction.amount < 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final incoming = current.transactions
        .where((transaction) => transaction.amount > 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final ratio = incoming == 0 ? 0 : outgoing / incoming;

    if (ratio > 0.70) {
      return 'High spend alert: outgoing payments are above 70% of recent income. Reduce merchant and transfer spend this week.';
    }
    if (outgoing > 1500) {
      return 'Weekly tip: set a MYR 1,000 discretionary cap to keep transfers and QR payments under control.';
    }
    return 'Healthy pattern: recent earning is ahead of expense. Keep 20% of incoming money in savings.';
  }

  Future<void> initialize() async {
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _initializePushNotifications();
      _session = await backend.restoreSession();
    } on Object catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  void selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }

    _selectedIndex = index;
    notifyListeners();
  }

  void toggleDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  Future<bool> register(RegistrationPayload payload) async {
    if (!_isSixDigit(payload.emailOtp) ||
        !_isSixDigit(payload.authenticatorCode)) {
      _setError('Complete all MFA codes before creating the account.');
      return false;
    }

    return _run(() async {
      _session = await backend.register(payload);
      _selectedIndex = 0;
      _setSuccess('Account secured and ready.');
    });
  }

  Future<void> requestLoginOtp(String email) async {
    if (email.trim().isEmpty) {
      _setError('Enter your email before requesting login OTP.');
      return;
    }

    await _run(() async {
      final challenge = await backend.requestOtpChallenge(
        purpose: 'login',
        email: email.trim(),
      );
      _loginOtpChallengeId = challenge.challengeId;
      _loginOtpPreview = challenge.demoCode;
      _setSuccess(challenge.message);
    });
  }

  Future<void> requestTransactionOtp() async {
    final current = _session;
    if (current == null) {
      return;
    }

    await _run(() async {
      final challenge = await backend.requestOtpChallenge(
        purpose: 'transaction',
        email: current.profile.email,
      );
      _transactionOtpChallengeId = challenge.challengeId;
      _transactionOtpPreview = challenge.demoCode;
      _setSuccess(challenge.message);
    });
  }

  Future<bool> login({
    required String email,
    required String password,
    required String oneTimeCode,
  }) async {
    if (!_isSixDigit(oneTimeCode)) {
      _setError('Enter the 6-digit email OTP to continue.');
      return false;
    }
    if (_loginOtpPreview.isNotEmpty && oneTimeCode.trim() != _loginOtpPreview) {
      _setError('The email OTP was not accepted.');
      return false;
    }
    if (isFirebaseBacked && _loginOtpChallengeId == null) {
      _setError('Request the email login OTP before continuing.');
      return false;
    }

    return _run(() async {
      _session = await backend.login(
        email: email,
        password: password,
        otpChallengeId: _loginOtpChallengeId ?? 'demo-login',
        otpCode: oneTimeCode.trim(),
      );
      _loginOtpChallengeId = null;
      _transactionOtpChallengeId = null;
      _loginOtpPreview = '';
      _transactionOtpPreview = '';
      _selectedIndex = 0;
      _prependActivity(
        ActivityEvent(
          id: 'local-login',
          title: 'Zero-trust login',
          subtitle: 'Password, OTP, device posture, and authenticator passed',
          iconKey: 'shield',
          occurredAt: DateTime.now(),
        ),
      );
    });
  }

  Future<bool> requestPasswordReset(String email) async {
    return _run(() async {
      await backend.requestPasswordReset(email);
      _setSuccess('Password reset instructions sent.');
    });
  }

  Future<bool> updateProfile({
    required String fullName,
    required String phone,
    required String trustedDeviceName,
  }) async {
    final current = _session;
    if (current == null) {
      return false;
    }

    final updatedProfile = current.profile.copyWith(
      fullName: fullName,
      phone: phone,
      trustedDeviceName: trustedDeviceName,
    );

    return _run(() async {
      await backend.updateProfile(updatedProfile);
      _session = current.copyWith(profile: updatedProfile);
      _prependActivity(
        ActivityEvent(
          id: 'profile-${DateTime.now().microsecondsSinceEpoch}',
          title: 'Profile updated',
          subtitle: 'Personal details were refreshed',
          iconKey: 'badge',
          occurredAt: DateTime.now(),
        ),
      );
      _setSuccess('Profile saved.');
    });
  }

  Future<bool> depositToOwnAccount(double amount, {required String otp}) async {
    final current = _session;
    if (current == null) {
      return false;
    }
    if (!_isSixDigit(otp)) {
      _setError('Enter the 6-digit email transaction OTP.');
      return false;
    }
    if (_transactionOtpPreview.isNotEmpty &&
        otp.trim() != _transactionOtpPreview) {
      _setError('The email transaction OTP was not accepted.');
      return false;
    }
    if (isFirebaseBacked && _transactionOtpChallengeId == null) {
      _setError('Request the email transaction OTP first.');
      return false;
    }

    return _run(() async {
      _session = await backend.depositToOwnAccount(
        current: current,
        amount: amount,
        otpChallengeId: _transactionOtpChallengeId ?? 'demo-transaction',
        otpCode: otp.trim(),
      );
      _addAlert(
        'Deposit received',
        '${current.currency} ${amount.toStringAsFixed(2)} added to your account.',
      );
      _transactionOtpChallengeId = null;
      _transactionOtpPreview = '';
      _setSuccess('Deposit completed.');
    });
  }

  Future<bool> sendToAccount({
    required String accountNumber,
    required double amount,
    required String otp,
  }) async {
    final current = _session;
    if (current == null) {
      return false;
    }
    if (!_isSixDigit(otp)) {
      _setError('Enter the 6-digit email transaction OTP.');
      return false;
    }
    if (_transactionOtpPreview.isNotEmpty &&
        otp.trim() != _transactionOtpPreview) {
      _setError('The email transaction OTP was not accepted.');
      return false;
    }
    if (isFirebaseBacked && _transactionOtpChallengeId == null) {
      _setError('Request the email transaction OTP first.');
      return false;
    }

    return _run(() async {
      _session = await backend.sendToAccount(
        current: current,
        accountNumber: accountNumber,
        amount: amount,
        otpChallengeId: _transactionOtpChallengeId ?? 'demo-transaction',
        otpCode: otp.trim(),
      );
      _addAlert(
        'Transfer sent',
        '${current.currency} ${amount.toStringAsFixed(2)} sent securely.',
      );
      _transactionOtpChallengeId = null;
      _transactionOtpPreview = '';
      _setSuccess('Transfer sent.');
    });
  }

  Future<bool> payQrAccount({
    required String accountNumber,
    required double amount,
    required String otp,
  }) {
    return sendToAccount(
      accountNumber: accountNumber,
      amount: amount,
      otp: otp,
    );
  }

  Future<void> logout() async {
    await _run(() async {
      await backend.logout();
      _session = null;
      _selectedIndex = 0;
      _setSuccess('Signed out securely.');
    });
  }

  Future<void> recordQrScan(String code) async {
    final current = _session;
    if (current == null || code.trim().isEmpty) {
      return;
    }

    try {
      _session = await backend.recordQrPaymentScan(
        current: current,
        code: code.trim(),
      );
      _addAlert('QR code scanned', 'Payment code captured for review.');
      _successMessage = 'QR code captured for payment review.';
      _errorMessage = null;
      notifyListeners();
    } on Object catch (error) {
      _setError(_friendlyError(error));
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void sendSupportMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) {
      return;
    }

    final now = DateTime.now();
    _supportMessages.add(
      SupportMessage(text: clean, createdAt: now, isAdmin: false),
    );
    _supportMessages.add(
      SupportMessage(
        text:
            'Thanks. A support admin received your message and will review your account securely.',
        createdAt: now.add(const Duration(seconds: 1)),
        isAdmin: true,
      ),
    );
    _addAlert('Support message sent', 'FINTRUST Support has your request.');
    notifyListeners();
  }

  Future<void> captureCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setError('Location permission is required for GPS security checks.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _lastLocation = LocationSnapshot(
        latitude: position.latitude,
        longitude: position.longitude,
        capturedAt: DateTime.now(),
      );
      _addAlert('Location verified', 'GPS signal attached to this session.');
      _setSuccess('Location verified.');
      notifyListeners();
    } on Object catch (error) {
      _setError(_friendlyError(error));
    }
  }

  String receiveQrPayload({double? amount}) {
    final current = _session;
    if (current == null) {
      return '';
    }

    final amountPart = amount == null
        ? ''
        : '|amount=${amount.toStringAsFixed(2)}';
    return 'FINTRUST|account=${current.profile.accountNumber}$amountPart';
  }

  Future<bool> _run(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on Object catch (error) {
      _setError(_friendlyError(error));
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _prependActivity(ActivityEvent event) {
    final current = _session;
    if (current == null) {
      return;
    }

    _session = current.copyWith(activity: [event, ...current.activity]);
  }

  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
  }

  void _addAlert(String title, String body) {
    _alerts.insert(
      0,
      NotificationAlert(title: title, body: body, createdAt: DateTime.now()),
    );
  }

  Future<void> _initializePushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _pushToken = await messaging.getToken();
      _addAlert(
        'Push notifications enabled',
        'FINTRUST can now alert you about transfers, QR scans, and support updates.',
      );
      FirebaseMessaging.onMessage.listen((message) {
        _addAlert(
          message.notification?.title ?? 'FINTRUST alert',
          message.notification?.body ?? 'You have a new secure account alert.',
        );
        notifyListeners();
      });
    } on Object {
      _addAlert(
        'Notification preview active',
        'Device push setup will finish when Firebase messaging is available.',
      );
    }
  }

  bool _isSixDigit(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value.trim());
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('firebase_auth/email-already-in-use')) {
      return 'That email is already registered.';
    }
    if (raw.contains('firebase_auth/invalid-credential') ||
        raw.contains('firebase_auth/wrong-password')) {
      return 'The email, password, or trust challenge was not accepted.';
    }
    if (raw.contains('network-request-failed')) {
      return 'Network verification failed. Please try again.';
    }
    if (raw.startsWith('Invalid argument')) {
      return raw.replaceFirst('Invalid argument(s): ', '');
    }

    return raw.replaceFirst('Exception: ', '');
  }
}

class FintrustScope extends InheritedNotifier<FintrustController> {
  const FintrustScope({
    required FintrustController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static FintrustController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FintrustScope>();
    assert(scope != null, 'FintrustScope was not found in the widget tree.');
    return scope!.notifier!;
  }

  static FintrustController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FintrustScope>();
    assert(scope != null, 'FintrustScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}
