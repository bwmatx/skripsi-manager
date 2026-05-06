import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/account/data/account_repository.dart';
import 'package:skripsi_manager/features/account/domain/account_model.dart';
import 'package:skripsi_manager/features/auth/presentation/change_pin_page.dart';
import 'package:skripsi_manager/features/notifications/data/notification_service.dart';

final accountProvider = FutureProvider<AccountModel>((ref) {
  return AccountRepository().getAccount();
});

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final account = await AccountRepository().getAccount();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EditAccountPage(account: account)),
              );
              ref.invalidate(accountProvider);
            },
          ),
        ],
      ),
      body: accountAsync.when(
        data: (account) => _AccountBody(account: account, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AccountBody extends StatefulWidget {
  final AccountModel account;
  final WidgetRef ref;
  const _AccountBody({required this.account, required this.ref});

  @override
  State<_AccountBody> createState() => _AccountBodyState();
}

class _AccountBodyState extends State<_AccountBody> {
  int _reminderHour = 9;
  int _reminderMinute = 0;
  bool _reminderEnabled = true;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked == null) return;
    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
    if (_reminderEnabled) {
      await NotificationService.scheduleDailyReminder(hour: _reminderHour, minute: _reminderMinute);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengingat dijadwalkan pukul ${picked.format(context)}')),
      );
    }
  }

  Future<void> _toggleReminder(bool val) async {
    setState(() => _reminderEnabled = val);
    if (val) {
      await NotificationService.scheduleDailyReminder(hour: _reminderHour, minute: _reminderMinute);
    } else {
      await NotificationService.cancelAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.primary.withAlpha(40),
                child: Text(
                  widget.account.name.isNotEmpty ? widget.account.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.account.name.isNotEmpty ? widget.account.name : 'Nama belum diisi',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                widget.account.thesisTitle.isNotEmpty ? widget.account.thesisTitle : 'Judul skripsi belum diisi',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Streak card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.account.currentStreak} Hari',
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const Text('Streak Aktif', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(label: 'Tanggal Lahir', value: widget.account.dateOfBirth.isNotEmpty ? widget.account.dateOfBirth : '-'),
        const SizedBox(height: 8),
        _InfoCard(
          label: 'Aktivitas Terakhir',
          value: widget.account.lastActivityDate.isNotEmpty ? _formatDate(widget.account.lastActivityDate) : '-',
        ),
        const SizedBox(height: 24),

        // ─── Reminder Section ───────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('PENGINGAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppTheme.textSecondary)),
        ),
        Container(
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.alarm_rounded, color: AppTheme.primary),
                ),
                title: const Text('Pengingat Harian', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Setiap hari pukul ${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                trailing: Switch(
                  value: _reminderEnabled,
                  onChanged: _toggleReminder,
                  activeTrackColor: AppTheme.primary.withAlpha(100),
                  activeThumbColor: AppTheme.primary,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.schedule_rounded, color: AppTheme.textSecondary),
                title: const Text('Atur Waktu Pengingat', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                onTap: _pickTime,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Change PIN
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePinPage())),
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Ganti PIN'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.divider),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('TENTANG APLIKASI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppTheme.textSecondary)),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Skripsi Manager', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                      Text('Version 1.1.0', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Developer', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('Adhi Wibowo', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Build Type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text('Release', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Edit Account Page ──────────────────────────────────────────────────────────

class EditAccountPage extends StatefulWidget {
  final AccountModel account;
  const EditAccountPage({super.key, required this.account});

  @override
  State<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage> {
  late final TextEditingController _name;
  late final TextEditingController _dob;
  late final TextEditingController _thesis;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.account.name);
    _dob = TextEditingController(text: widget.account.dateOfBirth);
    _thesis = TextEditingController(text: widget.account.thesisTitle);
  }

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    _thesis.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AccountRepository().saveAccount(AccountModel(
      name: _name.text.trim(),
      dateOfBirth: _dob.text.trim(),
      thesisTitle: _thesis.text.trim(),
      currentStreak: widget.account.currentStreak,
      lastActivityDate: widget.account.lastActivityDate,
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama')),
          const SizedBox(height: 16),
          TextField(
            controller: _dob,
            decoration: const InputDecoration(labelText: 'Tanggal Lahir (dd/mm/yyyy)'),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _thesis,
            decoration: const InputDecoration(labelText: 'Judul Skripsi'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
