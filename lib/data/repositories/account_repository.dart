import '../database/app_database.dart';
import '../models/account_model.dart';

class AccountRepository {
  final AppDatabase database;

  AccountRepository(this.database);

  Future<void> createDefaultWallet(int userId) async {
    final now = DateTime.now().toIso8601String();
    final accountNumber = 'ACC-${1000 + userId}';
    await database.db.insert(
      'accounts',
      AccountModel(
        userId: userId,
        accountNumber: accountNumber,
        currency: 'MYR',
        balance: 5000,
        createdAt: now,
      ).toMap(),
    );
  }

  Future<List<AccountModel>> getByUserId(int userId) async {
    final rows = await database.db.query(
      'accounts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(AccountModel.fromMap).toList();
  }

  Future<AccountModel?> findByNumberForUser(int userId, String accountNumber) async {
    final rows = await database.db.query(
      'accounts',
      where: 'user_id = ? AND account_number = ?',
      whereArgs: [userId, accountNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AccountModel.fromMap(rows.first);
  }

  Future<void> updateBalance(int accountId, double balance) async {
    await database.db.update(
      'accounts',
      {'balance': balance},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }
}
