import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/auth/data/auth_repository.dart';

class ChangePinPage extends StatefulWidget {
  // isSetup = true means first time (no old PIN needed)
  final bool isSetup;
  const ChangePinPage({super.key, this.isSetup = false});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  final _repo = AuthRepository();
  // Steps: 0 = enter old, 1 = enter new, 2 = confirm new
  int _step = 0;
  String _entered = '';
  String _newPin = '';
  bool _error = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    if (widget.isSetup) _step = 1;
  }

  void _onKey(String digit) {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == 6) _handleStep();
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _handleStep() async {
    if (_step == 0) {
      final saved = await _repo.getPin();
      if (_entered == saved) {
        setState(() { _step = 1; _entered = ''; });
      } else {
        HapticFeedback.mediumImpact();
        setState(() { _error = true; _errorMsg = 'PIN lama salah'; _entered = ''; });
      }
    } else if (_step == 1) {
      if (_entered.length < 6) return;
      setState(() { _newPin = _entered; _step = 2; _entered = ''; });
    } else {
      if (_entered == _newPin) {
        await _repo.setPin(_newPin);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN berhasil diubah')),
        );
        Navigator.of(context).pop();
      } else {
        HapticFeedback.mediumImpact();
        setState(() { _error = true; _errorMsg = 'Konfirmasi PIN tidak cocok'; _entered = ''; _step = 1; _newPin = ''; });
      }
    }
  }

  String get _title {
    if (_step == 0) return 'Masukkan PIN Lama';
    if (_step == 1) return 'Buat PIN Baru';
    return 'Konfirmasi PIN Baru';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ? _errorMsg : 'Masukkan 6 digit PIN',
                style: TextStyle(
                  fontSize: 13,
                  color: _error ? AppTheme.error : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
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
              const Spacer(),
              _Numpad(onKey: _onKey, onDelete: _onDelete),
              const Spacer(),
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
                    ? const Icon(Icons.backspace_rounded, color: AppTheme.textSecondary, size: 20)
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
