import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/core/database.dart';
import 'package:skripsi_manager/features/auth/presentation/pin_login_page.dart';
import 'package:skripsi_manager/features/notifications/data/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error handler — prevents hard crash
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  // Global async/platform error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[AppError] $error\n$stack');
    return true; // mark as handled — keep app alive
  };

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Init DB — fire-and-forget (safe)
  unawaited(Future(() async {
    try {
      await AppDatabase.instance;
    } catch (e) {
      debugPrint('[DB] Init failed: $e');
    }
  }));

  // Init NotificationService — must complete before UI is interactive
  // so timezone and channels are ready when user opens Pengingat page.
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('[Notif] Init failed: $e');
  }

  runApp(const ProviderScope(child: SkripsiApp()));
}

class SkripsiApp extends StatelessWidget {
  const SkripsiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skripsi Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const PinLoginPage(),
    );
  }
}
