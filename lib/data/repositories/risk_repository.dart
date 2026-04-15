import '../database/app_database.dart';
import '../models/risk_event_model.dart';

class RiskRepository {
  final AppDatabase database;

  RiskRepository(this.database);

  Future<int> create(RiskEventModel model) async {
    return database.db.insert('risk_events', model.toMap());
  }

  Future<List<RiskEventModel>> getByUserId(int userId) async {
    final rows = await database.db.query(
      'risk_events',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(RiskEventModel.fromMap).toList();
  }
}
