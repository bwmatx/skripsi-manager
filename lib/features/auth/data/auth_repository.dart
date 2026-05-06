import 'package:skripsi_manager/core/database.dart';

class AuthRepository {
  Future<String> getPin() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: ['pin']);
    if (rows.isEmpty) return '123123';
    return rows.first['value'] as String;
  }

  Future<void> setPin(String pin) async {
    final db = await AppDatabase.instance;
    await db.update('settings', {'value': pin}, where: 'key = ?', whereArgs: ['pin']);
  }
}
