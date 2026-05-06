class AccountModel {
  final String name;
  final String dateOfBirth;
  final String thesisTitle;
  final int currentStreak;
  final String lastActivityDate;

  const AccountModel({
    required this.name,
    required this.dateOfBirth,
    required this.thesisTitle,
    required this.currentStreak,
    required this.lastActivityDate,
  });

  factory AccountModel.fromMap(Map<String, dynamic> m) => AccountModel(
        name: m['name'] as String? ?? '',
        dateOfBirth: m['date_of_birth'] as String? ?? '',
        thesisTitle: m['thesis_title'] as String? ?? '',
        currentStreak: m['current_streak'] as int? ?? 0,
        lastActivityDate: m['last_activity_date'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'date_of_birth': dateOfBirth,
        'thesis_title': thesisTitle,
        'current_streak': currentStreak,
        'last_activity_date': lastActivityDate,
      };
}
