import 'package:skripsi_manager/core/database.dart';
import 'package:skripsi_manager/features/account/domain/account_model.dart';

class AccountRepository {
  Future<AccountModel> getAccount() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('account', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) {
      return const AccountModel(
          name: '', dateOfBirth: '', thesisTitle: '', currentStreak: 0, lastActivityDate: '');
    }
    return AccountModel.fromMap(rows.first);
  }

  Future<void> saveAccount(AccountModel model) async {
    final db = await AppDatabase.instance;
    await db.update('account', model.toMap(), where: 'id = ?', whereArgs: [1]);
  }

  Future<void> submitProgress() async {
    final account = await getAccount();
    final today = _dateOnly(DateTime.now());
    final last = account.lastActivityDate;

    int streak = account.currentStreak;

    if (last.isEmpty) {
      streak = 1;
    } else {
      final lastDate = DateTime.tryParse(last);
      if (lastDate != null) {
        final lastDay = _dateOnly(lastDate);
        final diff = today.difference(lastDay).inDays;
        if (diff == 0) {
          // Same day – no change
        } else if (diff == 1) {
          streak += 1;
        } else {
          streak = 1; // Reset
        }
      }
    }

    await saveAccount(AccountModel(
      name: account.name,
      dateOfBirth: account.dateOfBirth,
      thesisTitle: account.thesisTitle,
      currentStreak: streak,
      lastActivityDate: today.toIso8601String(),
    ));
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
