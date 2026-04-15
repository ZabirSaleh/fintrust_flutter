class AccountModel {
  final int? id;
  final int userId;
  final String accountNumber;
  final String currency;
  final double balance;
  final String createdAt;

  const AccountModel({
    this.id,
    required this.userId,
    required this.accountNumber,
    required this.currency,
    required this.balance,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'account_number': accountNumber,
        'currency': currency,
        'balance': balance,
        'created_at': createdAt,
      };

  factory AccountModel.fromMap(Map<String, dynamic> map) => AccountModel(
        id: map['id'] as int?,
        userId: map['user_id'] as int,
        accountNumber: map['account_number'] as String,
        currency: map['currency'] as String,
        balance: (map['balance'] as num).toDouble(),
        createdAt: map['created_at'] as String,
      );
}
