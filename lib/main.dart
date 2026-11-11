import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_theme.dart';
import 'core/database/database_helper.dart';
import 'core/services/notification_service.dart';
import 'features/settings/controllers/settings_controller.dart';
import 'shared/widgets/responsive_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização nativa para Desktop (Windows / Linux / macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Pré-inicializa o banco SQLite e o serviço unificado de notificações nativas
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Database init warning: $e');
  }

  await NotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: AlugPlusApp(),
    ),
  );
}

class AlugPlusApp extends ConsumerWidget {
  const AlugPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);

    return MaterialApp(
      title: 'AlugPlus+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsState.themeMode,
      home: const ResponsiveScaffold(),
    );
  }
}
