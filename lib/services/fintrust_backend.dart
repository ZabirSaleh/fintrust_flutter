import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

enum VerificationFactor {
  email,
  phone,
  identityDocument,
  oneTimePasscode,
  authenticator,
}

extension VerificationFactorLabels on VerificationFactor {
  String get label {
    return switch (this) {
      VerificationFactor.email => 'Email',
      VerificationFactor.phone => 'Phone',
      VerificationFactor.identityDocument => 'ID card',
      VerificationFactor.oneTimePasscode => 'OTP',
      VerificationFactor.authenticator => 'Authenticator',
    };
  }
}

class RegistrationPayload {
  const RegistrationPayload({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.idType,
    required this.idNumber,
    required this.password,
    required this.emailOtp,
    required this.authenticatorCode,
  });

  final String fullName;
  final String email;
  final String phone;
  final String idType;
  final String idNumber;
  final String password;
  final String emailOtp;
  final String authenticatorCode;
}

class OtpChallenge {
  const OtpChallenge({
    required this.challengeId,
    required this.message,
    this.demoCode = '',
  });

  final String challengeId;
  final String message;
  final String demoCode;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.accountNumber,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.idType,
    required this.maskedIdNumber,
    required this.country,
    required this.trustedDeviceName,
    required this.joinedAt,
    required this.verificationFactors,
    required this.riskScore,
    required this.credentialHash,
  });

  final String id;
  final String accountNumber;
  final String fullName;
  final String email;
  final String phone;
  final String idType;
  final String maskedIdNumber;
  final String country;
  final String trustedDeviceName;
  final DateTime joinedAt;
  final Set<VerificationFactor> verificationFactors;
  final int riskScore;
  final String credentialHash;

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? trustedDeviceName,
    int? riskScore,
  }) {
    return UserProfile(
      id: id,
      accountNumber: accountNumber,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      idType: idType,
      maskedIdNumber: maskedIdNumber,
      country: country,
      trustedDeviceName: trustedDeviceName ?? this.trustedDeviceName,
      joinedAt: joinedAt,
      verificationFactors: verificationFactors,
      riskScore: riskScore ?? this.riskScore,
      credentialHash: credentialHash,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'fullName': fullName,
      'accountNumber': accountNumber,
      'email': email,
      'phone': phone,
      'idType': idType,
      'maskedIdNumber': maskedIdNumber,
      'country': country,
      'trustedDeviceName': trustedDeviceName,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'riskScore': riskScore,
      'credentialHash': credentialHash,
      'verificationFactors': verificationFactors
          .map((factor) => factor.name)
          .toList(),
    };
  }

  factory UserProfile.fromJson(String id, Map<String, Object?> json) {
    return UserProfile(
      id: id,
      accountNumber: json['accountNumber'] as String? ?? _accountNumberFor(id),
      fullName: json['fullName'] as String? ?? 'FINTRUST Member',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      idType: json['idType'] as String? ?? 'Passport',
      maskedIdNumber: json['maskedIdNumber'] as String? ?? '**** 2042',
      country: json['country'] as String? ?? 'Malaysia',
      trustedDeviceName: json['trustedDeviceName'] as String? ?? 'This device',
      joinedAt: _dateFrom(json['joinedAt']),
      riskScore: (json['riskScore'] as num?)?.round() ?? 96,
      credentialHash: json['credentialHash'] as String? ?? _credentialHash(id),
      verificationFactors: _factorsFrom(json['verificationFactors']),
    );
  }
}

class FinTransaction {
  const FinTransaction({
    required this.id,
    required this.title,
    required this.counterparty,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.status,
    required this.category,
    required this.occurredAt,
    this.previousHash = 'GENESIS',
    this.transactionHash = '',
    this.blockIndex = 0,
    this.chainStatus = '',
    this.chainTxHash = '',
    this.chainContract = '',
    this.chainNetwork = '',
  });

  final String id;
  final String title;
  final String counterparty;
  final double amount;
  final String currency;
  final String direction;
  final String status;
  final String category;
  final DateTime occurredAt;
  final String previousHash;
  final String transactionHash;
  final int blockIndex;
  final String chainStatus;
  final String chainTxHash;
  final String chainContract;
  final String chainNetwork;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'counterparty': counterparty,
      'amount': amount,
      'currency': currency,
      'direction': direction,
      'status': status,
      'category': category,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'previousHash': previousHash,
      'transactionHash': transactionHash,
      'blockIndex': blockIndex,
      'chainStatus': chainStatus,
      'chainTxHash': chainTxHash,
      'chainContract': chainContract,
      'chainNetwork': chainNetwork,
    };
  }

  factory FinTransaction.fromJson(String id, Map<String, Object?> json) {
    return FinTransaction(
      id: id,
      title: json['title'] as String? ?? 'Transaction',
      counterparty: json['counterparty'] as String? ?? 'Unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'MYR',
      direction: json['direction'] as String? ?? 'Outgoing',
      status: json['status'] as String? ?? 'Pending',
      category: json['category'] as String? ?? 'General',
      occurredAt: _dateFrom(json['occurredAt']),
      previousHash: json['previousHash'] as String? ?? 'GENESIS',
      transactionHash: json['transactionHash'] as String? ?? '',
      blockIndex: (json['blockIndex'] as num?)?.round() ?? 0,
      chainStatus: json['chainStatus'] as String? ?? '',
      chainTxHash: json['chainTxHash'] as String? ?? '',
      chainContract: json['chainContract'] as String? ?? '',
      chainNetwork: json['chainNetwork'] as String? ?? '',
    );
  }
}

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.occurredAt,
    this.isCritical = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconKey;
  final DateTime occurredAt;
  final bool isCritical;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'iconKey': iconKey,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'isCritical': isCritical,
    };
  }

  factory ActivityEvent.fromJson(String id, Map<String, Object?> json) {
    return ActivityEvent(
      id: id,
      title: json['title'] as String? ?? 'Activity',
      subtitle: json['subtitle'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? 'history',
      occurredAt: _dateFrom(json['occurredAt']),
      isCritical: json['isCritical'] as bool? ?? false,
    );
  }
}

class BackendSession {
  const BackendSession({
    required this.profile,
    required this.balance,
    required this.currency,
    required this.transactions,
    required this.activity,
  });

  final UserProfile profile;
  final double balance;
  final String currency;
  final List<FinTransaction> transactions;
  final List<ActivityEvent> activity;

  BackendSession copyWith({
    UserProfile? profile,
    double? balance,
    List<FinTransaction>? transactions,
    List<ActivityEvent>? activity,
  }) {
    return BackendSession(
      profile: profile ?? this.profile,
      balance: balance ?? this.balance,
      currency: currency,
      transactions: transactions ?? this.transactions,
      activity: activity ?? this.activity,
    );
  }
}

abstract class FintrustBackend {
  String get modeLabel;

  bool get isFirebaseBacked;

  Future<BackendSession?> restoreSession();

  Future<BackendSession> register(RegistrationPayload payload);

  Future<BackendSession> login({
    required String email,
    required String password,
    required String otpChallengeId,
    required String otpCode,
  });

  Future<void> requestPasswordReset(String email);

  Future<OtpChallenge> requestOtpChallenge({
    required String purpose,
    String email = '',
  });

  Future<void> updateProfile(UserProfile profile);

  Future<BackendSession> depositToOwnAccount({
    required BackendSession current,
    required double amount,
    required String otpChallengeId,
    required String otpCode,
  });

  Future<BackendSession> sendToAccount({
    required BackendSession current,
    required String accountNumber,
    required double amount,
    required String otpChallengeId,
    required String otpCode,
  });

  Future<BackendSession> recordQrPaymentScan({
    required BackendSession current,
    required String code,
  });

  Future<void> logout();
}

class FintrustBackendFactory {
  static Future<FintrustBackend> create() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return FirebaseFintrustBackend(
        auth: firebase_auth.FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        functions: FirebaseFunctions.instance,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('FINTRUST Firebase fallback enabled: $error');
      debugPrintStack(stackTrace: stackTrace);
      return DemoFintrustBackend(disabledReason: error.toString());
    }
  }
}

class FirebaseFintrustBackend implements FintrustBackend {
  FirebaseFintrustBackend({
    required this.auth,
    required this.firestore,
    required this.functions,
  });

  final firebase_auth.FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  @override
  String get modeLabel => 'Firebase connected';

  @override
  bool get isFirebaseBacked => true;

  @override
  Future<BackendSession?> restoreSession() async {
    final user = auth.currentUser;
    if (user == null) {
      return null;
    }

    return _sessionForUser(user);
  }

  @override
  Future<BackendSession> register(RegistrationPayload payload) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: payload.email,
      password: payload.password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Account creation did not return a user.');
    }

    await user.updateDisplayName(payload.fullName);

    final profile = UserProfile(
      id: user.uid,
      accountNumber: _accountNumberFor(user.uid),
      fullName: payload.fullName,
      email: payload.email,
      phone: payload.phone,
      idType: payload.idType,
      maskedIdNumber: _maskIdentity(payload.idNumber),
      country: 'Malaysia',
      trustedDeviceName: 'Primary mobile device',
      joinedAt: DateTime.now(),
      riskScore: 98,
      credentialHash: _credentialHashForRegistration(payload),
      verificationFactors: const {
        VerificationFactor.email,
        VerificationFactor.identityDocument,
        VerificationFactor.oneTimePasscode,
        VerificationFactor.authenticator,
      },
    );

    await _createUserProfile(profile);
    await _ensureStarterData(profile);
    await _audit(
      profile.id,
      'Account registered',
      'Zero-trust enrolment passed',
      iconKey: 'shield',
    );

    return _sessionForUser(user);
  }

  @override
  Future<BackendSession> login({
    required String email,
    required String password,
    required String otpChallengeId,
    required String otpCode,
  }) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Sign-in did not return a user.');
    }

    try {
      await functions.httpsCallable('verifyOtp').call({
        'purpose': 'login',
        'challengeId': otpChallengeId,
        'code': otpCode,
        'email': email,
      });
    } on Object {
      await auth.signOut();
      rethrow;
    }

    final session = await _sessionForUser(user);
    await _audit(
      user.uid,
      'Login approved',
      'MFA challenge completed',
      iconKey: 'shield',
    );
    return session;
  }

  @override
  Future<void> requestPasswordReset(String email) {
    return auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<OtpChallenge> requestOtpChallenge({
    required String purpose,
    String email = '',
  }) async {
    final response = await functions.httpsCallable('requestOtp').call({
      'purpose': purpose,
      'email': email.isEmpty ? auth.currentUser?.email ?? '' : email,
    });
    final data = Map<String, Object?>.from(response.data as Map);
    final delivery = data['delivery'] as String? ?? 'email';
    return OtpChallenge(
      challengeId: data['challengeId'] as String? ?? '',
      message: 'FINTRUST OTP sent by $delivery.',
    );
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    await _userDoc(profile.id).set(
      profile.toJson()..['updatedAt'] = FieldValue.serverTimestamp(),
      SetOptions(merge: true),
    );
    await _audit(
      profile.id,
      'Profile updated',
      'Personal details were refreshed',
      iconKey: 'badge',
    );
  }

  @override
  Future<BackendSession> depositToOwnAccount({
    required BackendSession current,
    required double amount,
    required String otpChallengeId,
    required String otpCode,
  }) async {
    _ensurePositiveAmount(amount);
    await functions.httpsCallable('executeTransaction').call({
      'type': 'deposit',
      'amount': amount,
      'challengeId': otpChallengeId,
      'code': otpCode,
    });

    return _sessionForUser(auth.currentUser!);
  }

  @override
  Future<BackendSession> sendToAccount({
    required BackendSession current,
    required String accountNumber,
    required double amount,
    required String otpChallengeId,
    required String otpCode,
  }) async {
    _ensurePositiveAmount(amount);
    final normalizedAccount = _normalizeAccountNumber(accountNumber);
    if (normalizedAccount == current.profile.accountNumber) {
      throw ArgumentError('You cannot send money to your own account.');
    }
    if (current.balance < amount) {
      throw ArgumentError('Insufficient balance.');
    }

    await functions.httpsCallable('executeTransaction').call({
      'type': 'send',
      'recipientAccount': normalizedAccount,
      'amount': amount,
      'challengeId': otpChallengeId,
      'code': otpCode,
    });

    return _sessionForUser(auth.currentUser!);
  }

  @override
  Future<BackendSession> recordQrPaymentScan({
    required BackendSession current,
    required String code,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('The Firebase session expired. Please sign in again.');
    }

    final now = DateTime.now();
    final clippedCode = _clipCode(code);
    final activity = ActivityEvent(
      id: 'qr-act-${now.microsecondsSinceEpoch}',
      title: 'QR pay code captured',
      subtitle: clippedCode,
      iconKey: 'scan',
      occurredAt: now,
    );

    final batch = firestore.batch();
    batch.set(_activityDoc(user.uid, activity.id), activity.toJson());
    await batch.commit();

    return current.copyWith(activity: [activity, ...current.activity]);
  }

  @override
  Future<void> logout() async {
    await auth.signOut();
  }

  Future<BackendSession> _sessionForUser(firebase_auth.User user) async {
    final profile = await _profileForUser(user);
    await _ensureStarterData(profile);

    final walletDoc = await _walletDoc(user.uid).get();
    final wallet = walletDoc.data() ?? <String, Object?>{};

    final transactionSnap = await _transactions(
      user.uid,
    ).orderBy('occurredAt', descending: true).limit(30).get();
    final activitySnap = await _activity(
      user.uid,
    ).orderBy('occurredAt', descending: true).limit(30).get();

    return BackendSession(
      profile: profile,
      balance: (wallet['balance'] as num?)?.toDouble() ?? 18420.75,
      currency: wallet['currency'] as String? ?? 'MYR',
      transactions: transactionSnap.docs
          .map((doc) => FinTransaction.fromJson(doc.id, doc.data()))
          .toList(),
      activity: activitySnap.docs
          .map((doc) => ActivityEvent.fromJson(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<UserProfile> _profileForUser(firebase_auth.User user) async {
    final doc = await _userDoc(user.uid).get();
    if (doc.exists) {
      final profile = UserProfile.fromJson(
        user.uid,
        doc.data() ?? <String, Object?>{},
      );
      await _createUserProfile(profile);
      return profile;
    }

    final profile = _profileFromFirebaseUser(user);
    await _createUserProfile(profile);
    return profile;
  }

  Future<void> _createUserProfile(UserProfile profile) {
    final batch = firestore.batch();
    batch.set(_userDoc(profile.id), {
      ...profile.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_accountDirectoryDoc(profile.accountNumber), {
      'uid': profile.id,
      'accountNumber': profile.accountNumber,
      'fullName': profile.fullName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return batch.commit();
  }

  Future<void> _ensureStarterData(UserProfile profile) async {
    final walletDoc = await _walletDoc(profile.id).get();
    final activityDoc = await _activity(profile.id).limit(1).get();

    final batch = firestore.batch();
    var shouldCommit = false;

    if (!walletDoc.exists) {
      batch.set(_walletDoc(profile.id), {
        'balance': 18420.75,
        'currency': 'MYR',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      shouldCommit = true;
    }

    if (activityDoc.docs.isEmpty) {
      for (final event in _sampleActivity(profile.fullName)) {
        batch.set(_activityDoc(profile.id, event.id), event.toJson());
      }
      shouldCommit = true;
    }

    if (shouldCommit) {
      await batch.commit();
    }
  }

  Future<void> _audit(
    String uid,
    String title,
    String subtitle, {
    required String iconKey,
  }) {
    final now = DateTime.now();
    return _activityDoc(uid, 'audit-${now.microsecondsSinceEpoch}').set(
      ActivityEvent(
        id: 'audit-${now.microsecondsSinceEpoch}',
        title: title,
        subtitle: subtitle,
        iconKey: iconKey,
        occurredAt: now,
      ).toJson(),
    );
  }

  DocumentReference<Map<String, Object?>> _userDoc(String uid) {
    return firestore.collection('users').doc(uid);
  }

  DocumentReference<Map<String, Object?>> _accountDirectoryDoc(
    String accountNumber,
  ) {
    return firestore.collection('accountDirectory').doc(accountNumber);
  }

  DocumentReference<Map<String, Object?>> _walletDoc(String uid) {
    return _userDoc(uid).collection('wallets').doc('main');
  }

  CollectionReference<Map<String, Object?>> _transactions(String uid) {
    return _userDoc(uid).collection('transactions');
  }

  CollectionReference<Map<String, Object?>> _activity(String uid) {
    return _userDoc(uid).collection('activity');
  }

  DocumentReference<Map<String, Object?>> _activityDoc(
    String uid,
    String activityId,
  ) {
    return _activity(uid).doc(activityId);
  }
}

class DemoFintrustBackend implements FintrustBackend {
  DemoFintrustBackend({this.disabledReason});

  final String? disabledReason;

  @override
  String get modeLabel => disabledReason == null
      ? 'Demo secure mode'
      : 'Demo mode until Firebase is configured';

  @override
  bool get isFirebaseBacked => false;

  @override
  Future<BackendSession?> restoreSession() async {
    return null;
  }

  @override
  Future<BackendSession> register(RegistrationPayload payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final profile = UserProfile(
      id: 'demo-${payload.email.hashCode.abs()}',
      accountNumber: _accountNumberFor('demo-${payload.email.hashCode.abs()}'),
      fullName: payload.fullName,
      email: payload.email,
      phone: payload.phone,
      idType: payload.idType,
      maskedIdNumber: _maskIdentity(payload.idNumber),
      country: 'Malaysia',
      trustedDeviceName: 'Primary mobile device',
      joinedAt: DateTime.now(),
      riskScore: 98,
      credentialHash: _credentialHashForRegistration(payload),
      verificationFactors: const {
        VerificationFactor.email,
        VerificationFactor.identityDocument,
        VerificationFactor.oneTimePasscode,
        VerificationFactor.authenticator,
      },
    );

    return _demoSessionFor(profile);
  }

  @override
  Future<BackendSession> login({
    required String email,
    required String password,
    required String otpChallengeId,
    required String otpCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 380));

    if (password.length < 8) {
      throw ArgumentError('Use at least 8 characters for the password.');
    }
    if (otpCode != '123456') {
      throw ArgumentError('Demo email OTP is 123456.');
    }

    return _demoSessionFor(_demoProfile(email));
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<OtpChallenge> requestOtpChallenge({
    required String purpose,
    String email = '',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return OtpChallenge(
      challengeId: 'demo-$purpose-${email.hashCode.abs()}',
      demoCode: '123456',
      message: 'Demo FINTRUST email OTP generated. Use 123456.',
    );
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  @override
  Future<BackendSession> depositToOwnAccount({
    required BackendSession current,
    required double amount,
    required String otpChallengeId,
    required String otpCode,
  }) async {
    _ensurePositiveAmount(amount);
    if (otpCode != '123456') {
      throw ArgumentError('Demo email OTP is 123456.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final now = DateTime.now();
    final transaction = _securedTransaction(
      id: 'demo-dep-${now.microsecondsSinceEpoch}',
      title: 'Deposit',
      counterparty: current.profile.accountNumber,
      amount: amount,
      currency: current.currency,
      direction: 'Incoming',
      status: 'Settled',
      category: 'Deposit',
      occurredAt: now,
      previousHash: _latestTransactionHash(current.transactions),
      blockIndex: current.transactions.length + 1,
    );
    final activity = ActivityEvent(
      id: 'demo-dep-act-${now.microsecondsSinceEpoch}',
      title: 'Deposit received',
      subtitle: '${current.currency} ${amount.toStringAsFixed(2)} added',
      iconKey: 'deposit',
      occurredAt: now,
    );

    return current.copyWith(
      balance: current.balance + amount,
      transactions: [transaction, ...current.transactions],
      activity: [activity, ...current.activity],
    );
  }

  @override
  Future<BackendSession> sendToAccount({
    required BackendSession current,
    required String accountNumber,
    required double amount,
    required String otpChallengeId,
    required String otpCode,
  }) async {
    _ensurePositiveAmount(amount);
    if (otpCode != '123456') {
      throw ArgumentError('Demo email OTP is 123456.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 280));

    final normalizedAccount = _normalizeAccountNumber(accountNumber);
    if (normalizedAccount == current.profile.accountNumber) {
      throw ArgumentError('You cannot send money to your own account.');
    }
    if (current.balance < amount) {
      throw ArgumentError('Insufficient balance.');
    }

    final now = DateTime.now();
    final transaction = _securedTransaction(
      id: 'demo-send-${now.microsecondsSinceEpoch}',
      title: 'Transfer sent',
      counterparty: normalizedAccount,
      amount: -amount,
      currency: current.currency,
      direction: 'Outgoing',
      status: 'Settled',
      category: 'Transfer',
      occurredAt: now,
      previousHash: _latestTransactionHash(current.transactions),
      blockIndex: current.transactions.length + 1,
    );
    final activity = ActivityEvent(
      id: 'demo-send-act-${now.microsecondsSinceEpoch}',
      title: 'Transfer sent',
      subtitle: 'Sent ${current.currency} ${amount.toStringAsFixed(2)}',
      iconKey: 'transfer',
      occurredAt: now,
    );

    return current.copyWith(
      balance: current.balance - amount,
      transactions: [transaction, ...current.transactions],
      activity: [activity, ...current.activity],
    );
  }

  @override
  Future<BackendSession> recordQrPaymentScan({
    required BackendSession current,
    required String code,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final now = DateTime.now();
    final clippedCode = _clipCode(code);
    final transaction = _securedTransaction(
      id: 'qr-${now.microsecondsSinceEpoch}',
      title: 'QR payment scanned',
      counterparty: clippedCode,
      amount: -0.00,
      currency: current.currency,
      direction: 'Outgoing',
      status: 'Awaiting approval',
      category: 'QR Pay',
      occurredAt: now,
      previousHash: _latestTransactionHash(current.transactions),
      blockIndex: current.transactions.length + 1,
    );
    final activity = ActivityEvent(
      id: 'qr-act-${now.microsecondsSinceEpoch}',
      title: 'QR pay code captured',
      subtitle: clippedCode,
      iconKey: 'scan',
      occurredAt: now,
    );

    return current.copyWith(
      transactions: [transaction, ...current.transactions],
      activity: [activity, ...current.activity],
    );
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }
}

BackendSession _demoSessionFor(UserProfile profile) {
  return BackendSession(
    profile: profile,
    balance: 18420.75,
    currency: 'MYR',
    transactions: _sampleTransactions(),
    activity: _sampleActivity(profile.fullName),
  );
}

UserProfile _demoProfile(String email) {
  return UserProfile(
    id: 'demo-member',
    accountNumber: _accountNumberFor('demo-member'),
    fullName: 'Ariana Shah',
    email: email.isEmpty ? 'ariana@fintrust.app' : email,
    phone: '+60 12 448 9010',
    idType: 'Passport',
    maskedIdNumber: '**** 2042',
    country: 'Malaysia',
    trustedDeviceName: 'iPhone 15 Pro',
    joinedAt: DateTime.now().subtract(const Duration(days: 214)),
    riskScore: 97,
    credentialHash: _credentialHash(email),
    verificationFactors: const {
      VerificationFactor.email,
      VerificationFactor.identityDocument,
      VerificationFactor.oneTimePasscode,
      VerificationFactor.authenticator,
    },
  );
}

UserProfile _profileFromFirebaseUser(firebase_auth.User user) {
  return UserProfile(
    id: user.uid,
    accountNumber: _accountNumberFor(user.uid),
    fullName: user.displayName ?? 'FINTRUST Member',
    email: user.email ?? '',
    phone: user.phoneNumber ?? '',
    idType: 'Passport',
    maskedIdNumber: 'Pending',
    country: 'Malaysia',
    trustedDeviceName: 'Primary mobile device',
    joinedAt: user.metadata.creationTime ?? DateTime.now(),
    riskScore: 92,
    credentialHash: _credentialHash(user.uid),
    verificationFactors: const {
      VerificationFactor.email,
      VerificationFactor.oneTimePasscode,
    },
  );
}

List<FinTransaction> _sampleTransactions() {
  final now = DateTime.now();

  return _chainTransactions([
    FinTransaction(
      id: 'txn-1001',
      title: 'QR Pay',
      counterparty: 'Kopi Ledger Cafe',
      amount: -18.90,
      currency: 'MYR',
      direction: 'Outgoing',
      status: 'Settled',
      category: 'Merchant',
      occurredAt: now.subtract(const Duration(hours: 3)),
    ),
    FinTransaction(
      id: 'txn-1002',
      title: 'Salary',
      counterparty: 'Northstar Labs',
      amount: 9200,
      currency: 'MYR',
      direction: 'Incoming',
      status: 'Settled',
      category: 'Income',
      occurredAt: now.subtract(const Duration(days: 2, hours: 4)),
    ),
    FinTransaction(
      id: 'txn-1003',
      title: 'Wise transfer',
      counterparty: 'Maya Chen',
      amount: -540.25,
      currency: 'MYR',
      direction: 'Outgoing',
      status: 'Processing',
      category: 'Transfer',
      occurredAt: now.subtract(const Duration(days: 3, hours: 2)),
    ),
    FinTransaction(
      id: 'txn-1004',
      title: 'Card refund',
      counterparty: 'Apple Services',
      amount: 29.90,
      currency: 'MYR',
      direction: 'Incoming',
      status: 'Settled',
      category: 'Refund',
      occurredAt: now.subtract(const Duration(days: 5)),
    ),
  ]);
}

List<ActivityEvent> _sampleActivity(String name) {
  final now = DateTime.now();

  return [
    ActivityEvent(
      id: 'act-1',
      title: 'Login approved',
      subtitle: 'Trusted device and authenticator matched for $name',
      iconKey: 'shield',
      occurredAt: now.subtract(const Duration(minutes: 12)),
    ),
    ActivityEvent(
      id: 'act-2',
      title: 'Transaction screened',
      subtitle: 'Transfer to Maya Chen cleared risk checks',
      iconKey: 'search',
      occurredAt: now.subtract(const Duration(days: 1, hours: 6)),
    ),
    ActivityEvent(
      id: 'act-3',
      title: 'Profile verified',
      subtitle: 'Passport and email MFA factors are active',
      iconKey: 'badge',
      occurredAt: now.subtract(const Duration(days: 9)),
    ),
  ];
}

DateTime _dateFrom(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  return DateTime.now();
}

Set<VerificationFactor> _factorsFrom(Object? value) {
  if (value is! Iterable) {
    return const {VerificationFactor.email, VerificationFactor.oneTimePasscode};
  }

  return value
      .whereType<String>()
      .map(
        (name) => VerificationFactor.values.firstWhere(
          (factor) => factor.name == name,
          orElse: () => VerificationFactor.oneTimePasscode,
        ),
      )
      .toSet();
}

String _maskIdentity(String raw) {
  final normalized = raw.trim().replaceAll(' ', '');
  if (normalized.length <= 4) {
    return '****';
  }

  return '**** ${normalized.substring(normalized.length - 4)}';
}

String _clipCode(String code) {
  final trimmed = code.trim();
  return trimmed.length > 42 ? '${trimmed.substring(0, 42)}...' : trimmed;
}

void _ensurePositiveAmount(double amount) {
  if (amount <= 0) {
    throw ArgumentError('Enter an amount greater than zero.');
  }
}

String _normalizeAccountNumber(String value) {
  final cleaned = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (cleaned.startsWith('FT') && cleaned.length >= 12) {
    return 'FT-${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
  }
  return value.trim().toUpperCase();
}

String _accountNumberFor(String seed) {
  final cleaned = seed
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .padRight(10, '0');
  final first = cleaned.substring(0, 4);
  final last = cleaned.substring(cleaned.length - 6);
  return 'FT-$first-$last';
}

String _credentialHashForRegistration(RegistrationPayload payload) {
  return _hashString(
    [
      payload.email.toLowerCase().trim(),
      payload.phone.trim(),
      payload.idType,
      _maskIdentity(payload.idNumber),
    ].join('|'),
  );
}

String _credentialHash(String seed) {
  return _hashString('FINTRUST-CREDENTIAL|$seed');
}

String _latestTransactionHash(List<FinTransaction> transactions) {
  for (final transaction in transactions) {
    if (transaction.transactionHash.isNotEmpty) {
      return transaction.transactionHash;
    }
  }
  return 'GENESIS';
}

FinTransaction _securedTransaction({
  required String id,
  required String title,
  required String counterparty,
  required double amount,
  required String currency,
  required String direction,
  required String status,
  required String category,
  required DateTime occurredAt,
  required String previousHash,
  required int blockIndex,
}) {
  final payload = [
    id,
    title,
    counterparty,
    amount.toStringAsFixed(2),
    currency,
    direction,
    status,
    category,
    occurredAt.toIso8601String(),
    previousHash,
    blockIndex,
  ].join('|');

  return FinTransaction(
    id: id,
    title: title,
    counterparty: counterparty,
    amount: amount,
    currency: currency,
    direction: direction,
    status: status,
    category: category,
    occurredAt: occurredAt,
    previousHash: previousHash,
    blockIndex: blockIndex,
    transactionHash: _hashString(payload),
  );
}

List<FinTransaction> _chainTransactions(List<FinTransaction> transactions) {
  var previousHash = 'GENESIS';
  final chained = <FinTransaction>[];
  for (var i = 0; i < transactions.length; i++) {
    final transaction = transactions[i];
    final secured = _securedTransaction(
      id: transaction.id,
      title: transaction.title,
      counterparty: transaction.counterparty,
      amount: transaction.amount,
      currency: transaction.currency,
      direction: transaction.direction,
      status: transaction.status,
      category: transaction.category,
      occurredAt: transaction.occurredAt,
      previousHash: previousHash,
      blockIndex: i + 1,
    );
    chained.add(secured);
    previousHash = secured.transactionHash;
  }
  return chained;
}

String _hashString(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}
