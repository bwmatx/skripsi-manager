import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/account/data/account_repository.dart';
import 'package:skripsi_manager/features/account/domain/account_model.dart';
import 'package:skripsi_manager/features/auth/presentation/change_pin_page.dart';
import 'package:skripsi_manager/features/ai/data/ai_provider.dart';
import 'package:skripsi_manager/features/ai/data/ai_settings_provider.dart';
import 'package:skripsi_manager/features/ai/data/ai_settings_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';


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
                MaterialPageRoute(
                  builder: (_) => EditAccountPage(account: account),
                ),
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
  String _versionStr = 'Version 1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _versionStr = 'Version ${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.primary.withAlpha(40),
                child: Text(
                  widget.account.name.isNotEmpty
                      ? widget.account.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.account.name.isNotEmpty
                    ? widget.account.name
                    : 'Nama belum diisi',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.account.thesisTitle.isNotEmpty
                    ? widget.account.thesisTitle
                    : 'Judul skripsi belum diisi',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
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
              const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.account.currentStreak} Hari',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Streak Aktif',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          label: 'Tanggal Lahir',
          value: widget.account.dateOfBirth.isNotEmpty
              ? widget.account.dateOfBirth
              : '-',
        ),
        const SizedBox(height: 8),
        _InfoCard(
          label: 'Aktivitas Terakhir',
          value: widget.account.lastActivityDate.isNotEmpty
              ? _formatDate(widget.account.lastActivityDate)
              : '-',
        ),
        const SizedBox(height: 24),
        // ─── AI Settings Section ───────────────────────────────────────────────
        const _AiSettingsSection(),
        const SizedBox(height: 24),


        // Change PIN
        OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ChangePinPage())),
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Ganti PIN'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.divider),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'TENTANG APLIKASI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Skripsi Manager',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _versionStr,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
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
                  Text(
                    'Developer',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Adhi Wibowo',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Build Type',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Stable Release',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
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
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
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
    await AccountRepository().saveAccount(
      AccountModel(
        name: _name.text.trim(),
        dateOfBirth: _dob.text.trim(),
        thesisTitle: _thesis.text.trim(),
        currentStreak: widget.account.currentStreak,
        lastActivityDate: widget.account.lastActivityDate,
      ),
    );
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
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dob,
            decoration: const InputDecoration(
              labelText: 'Tanggal Lahir (dd/mm/yyyy)',
            ),
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
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

// ── AI Settings Section ────────────────────────────────────────────────────────

class _AiSettingsSection extends ConsumerStatefulWidget {
  const _AiSettingsSection();

  @override
  ConsumerState<_AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<_AiSettingsSection> {
  late final TextEditingController _deepSeekCtrl;
  late final TextEditingController _openRouterCtrl;
  bool _obscureDeepSeek = true;
  bool _obscureOpenRouter = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _deepSeekCtrl = TextEditingController();
    _openRouterCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _deepSeekCtrl.dispose();
    _openRouterCtrl.dispose();
    super.dispose();
  }

  void _initControllers(AiSettings s) {
    if (_initialized) return;
    _deepSeekCtrl.text = s.deepSeekApiKey;
    _openRouterCtrl.text = s.openRouterApiKey;
    _initialized = true;
  }

  Future<void> _saveDeepSeek() async {
    await ref
        .read(aiSettingsNotifierProvider.notifier)
        .setDeepSeekKey(_deepSeekCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DeepSeek API key disimpan.')),
    );
  }

  Future<void> _saveOpenRouter() async {
    await ref
        .read(aiSettingsNotifierProvider.notifier)
        .setOpenRouterKey(_openRouterCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OpenRouter API key disimpan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(aiSettingsNotifierProvider);

    return settingsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text(
        'Gagal memuat pengaturan AI: $e',
        style: const TextStyle(color: AppTheme.error, fontSize: 12),
      ),
      data: (settings) {
        _initControllers(settings);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section label ──
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'PENGATURAN AI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Preferred Provider ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Provider AI Utama',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Provider yang digunakan pertama kali',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AiProviderType>(
                    initialValue: settings.preferredProvider,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.divider),
                      ),
                    ),
                    items: AiProviderType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.displayName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (t) {
                      if (t != null) {
                        ref
                            .read(aiSettingsNotifierProvider.notifier)
                            .setPreferredProvider(t);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Auto Fallback toggle ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto Fallback',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Coba provider lain jika gagal',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: settings.autoFallback,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (v) {
                          ref
                              .read(aiSettingsNotifierProvider.notifier)
                              .setAutoFallback(v);
                        },
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),

                  // ── DeepSeek API Key ──
                  const Text(
                    'DeepSeek API Key',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _deepSeekCtrl,
                          obscureText: _obscureDeepSeek,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'sk-xxxxxxxxxxxxxxxxxxxx',
                            hintStyle:
                                const TextStyle(color: AppTheme.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureDeepSeek
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () => setState(
                                () => _obscureDeepSeek = !_obscureDeepSeek,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _saveDeepSeek,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Simpan', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── OpenRouter API Key ──
                  const Text(
                    'OpenRouter API Key',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _openRouterCtrl,
                          obscureText: _obscureOpenRouter,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'sk-or-v1-xxxxxxxxxxxx',
                            hintStyle:
                                const TextStyle(color: AppTheme.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureOpenRouter
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () => setState(
                                () => _obscureOpenRouter = !_obscureOpenRouter,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _saveOpenRouter,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Simpan', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
