class RiskEventModel {
  final int? id;
  final int userId;
  final int? transactionId;
  final int score;
  final String band;
  final String decision;
  final String details;
  final String createdAt;

  const RiskEventModel({
    this.id,
    required this.userId,
    this.transactionId,
    required this.score,
    required this.band,
    required this.decision,
    required this.details,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'transaction_id': transactionId,
        'score': score,
        'band': band,
        'decision': decision,
        'details': details,
        'created_at': createdAt,
      };

  factory RiskEventModel.fromMap(Map<String, dynamic> map) => RiskEventModel(
        id: map['id'] as int?,
        userId: map['user_id'] as int,
        transactionId: map['transaction_id'] as int?,
        score: map['score'] as int,
        band: map['band'] as String,
        decision: map['decision'] as String,
        details: map['details'] as String,
        createdAt: map['created_at'] as String,
      );
}
