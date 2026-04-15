import '../database/app_database.dart';
import '../models/user_model.dart';

class UserRepository {
  final AppDatabase database;

  UserRepository(this.database);

  Future<UserModel?> findByEmail(String email) async {
    final rows = await database.db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<UserModel> create({
    required String email,
    required String fullName,
    required String password,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await database.db.insert(
      'users',
      UserModel(
        email: email.trim(),
        fullName: fullName.trim(),
        password: password,
        createdAt: now,
      ).toMap(),
    );

    return UserModel(
      id: id,
      email: email.trim(),
      fullName: fullName.trim(),
      password: password,
      createdAt: now,
    );
  }
}
