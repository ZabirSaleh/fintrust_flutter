class TransactionModel {
  final int? id;
  final int userId;
  final int fromAccountId;
  final String toAccountNumber;
  final double amount;
  final String currency;
  final String status;
  final String createdAt;

  const TransactionModel({
    this.id,
    required this.userId,
    required this.fromAccountId,
    required this.toAccountNumber,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'from_account_id': fromAccountId,
        'to_account_number': toAccountNumber,
        'amount': amount,
        'currency': currency,
        'status': status,
        'created_at': createdAt,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'] as int?,
        userId: map['user_id'] as int,
        fromAccountId: map['from_account_id'] as int,
        toAccountNumber: map['to_account_number'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String,
        status: map['status'] as String,
        createdAt: map['created_at'] as String,
      );
}
