import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/database/database_helper.dart';
import 'core/services/notification_service.dart';
import 'features/settings/controllers/settings_controller.dart';
import 'shared/widgets/responsive_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização do banco para Web e Desktop (Windows / Linux / macOS)
  DatabaseHelper.ensurePlatformInitialized();

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
