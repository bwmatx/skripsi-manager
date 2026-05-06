import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/notifications/data/notification_service.dart';

final _pendingProvider = FutureProvider<int>((ref) async {
  final list = await NotificationService.getPending();
  return list.length;
});

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
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
      await NotificationService.scheduleDailyReminder(
          hour: _reminderHour, minute: _reminderMinute);
      ref.invalidate(_pendingProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengingat dijadwalkan pukul ${picked.format(context)}')),
      );
    }
  }

  Future<void> _toggleReminder(bool val) async {
    setState(() => _reminderEnabled = val);
    if (val) {
      await NotificationService.scheduleDailyReminder(
          hour: _reminderHour, minute: _reminderMinute);
    } else {
      await NotificationService.cancelAll();
    }
    ref.invalidate(_pendingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(_pendingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active notifications badge
          pendingAsync.when(
            data: (count) => _InfoBanner(
              icon: Icons.notifications_active_rounded,
              text: '$count notifikasi terjadwal aktif',
              color: count > 0 ? AppTheme.success : AppTheme.textSecondary,
            ),
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
          const SizedBox(height: 16),
          // Daily reminder card
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.alarm_rounded, color: AppTheme.primary),
                  ),
                  title: const Text('Pengingat Harian',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
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
                  title: const Text('Atur Waktu Pengingat',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                  onTap: _pickTime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Info',
                    style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 10),
                const Text(
                  '• Pengingat harian akan muncul setiap hari pada waktu yang ditentukan.\n'
                  '• Notifikasi deadline akan muncul 1 hari sebelum tenggat waktu.\n'
                  '• Semua notifikasi berjalan secara offline.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBanner({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
