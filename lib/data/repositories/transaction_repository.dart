import '../database/app_database.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final AppDatabase database;

  TransactionRepository(this.database);

  Future<int> create(TransactionModel model) async {
    return database.db.insert('transactions', model.toMap());
  }
}
