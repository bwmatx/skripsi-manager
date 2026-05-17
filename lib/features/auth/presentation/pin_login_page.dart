import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/auth/data/auth_repository.dart';
import 'package:skripsi_manager/shared/main_shell.dart';
import 'package:skripsi_manager/features/auth/presentation/change_pin_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  final _repo = AuthRepository();
  String _entered = '';
  bool _error = false;
  bool _loading = false;
  String _versionStr = 'version 1.0.0 stable release';

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
          _versionStr = 'version ${info.version}+${info.buildNumber} stable release';
        });
      }
    } catch (_) {}
  }

  void _onKey(String digit) {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == 6) _verify();
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    final saved = await _repo.getPin();
    if (_entered == saved) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = true;
        _entered = '';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Icon(Icons.lock_rounded, size: 48, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Skripsi Manager',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Masukkan PIN untuk melanjutkan',
                style: TextStyle(
                  fontSize: 14,
                  color: _error ? AppTheme.error : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _entered.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _error
                          ? AppTheme.error
                          : filled
                          ? AppTheme.primary
                          : AppTheme.divider,
                    ),
                  );
                }),
              ),
              const Spacer(flex: 1),
              // Numpad
              _loading
                  ? const CircularProgressIndicator()
                  : _Numpad(onKey: _onKey, onDelete: _onDelete),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePinPage(isSetup: false),
                  ),
                ),
                child: const Text('Lupa PIN?'),
              ),
              const Spacer(flex: 1),
              Text(
                'App created by Adhi Wibowo\n$_versionStr',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onDelete;

  const _Numpad({required this.onKey, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];
    return Column(
      children: digits.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 80, height: 64);
            return GestureDetector(
              onTap: () => k == '<' ? onDelete() : onKey(k),
              child: Container(
                width: 80,
                height: 64,
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: k == '<'
                    ? const Icon(
                        Icons.backspace_rounded,
                        color: AppTheme.textSecondary,
                        size: 20,
                      )
                    : Text(
                        k,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
