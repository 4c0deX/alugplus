import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

import '../utils/time_utils.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _mobilePlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (_isDesktop) {
        await localNotifier.setup(
          appName: 'AlugPlus+',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
      } else if (_isMobile) {
        const androidSettings = AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        );
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _mobilePlugin.initialize(settings: initSettings);

        if (Platform.isAndroid) {
          final androidImpl = _mobilePlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          await androidImpl?.requestNotificationsPermission();
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init warning: $e');
    }
  }

  /// Envia notificação nativa quando o tempo contratado do aluguel chega ao fim.
  Future<void> notifyRentalFinished({
    required int rentalId,
    required String itemName,
  }) async {
    await _sendNotification(
      id: rentalId * 10 + 1,
      title: 'Tempo Esgotado • AlugPlus+',
      body:
          'O aluguel de "$itemName" atingiu o horário previsto de devolução.',
    );
  }

  /// Envia notificação nativa exatamente no minuto configurado de atraso avisando início de cobrança de acréscimo.
  Future<void> notifySurchargeStarted({
    required int rentalId,
    required String itemName,
  }) async {
    final min = TimeUtils.surchargeTriggerMinute;
    await _sendNotification(
      id: rentalId * 10 + 2,
      title: 'Acréscimo Iniciado ($minº min) • AlugPlus+',
      body:
          'Tolerância encerrada para "$itemName". Cobrança de acréscimo por atraso iniciada (R\$ 1,00/min).',
    );
  }

  Future<void> _sendNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (_isDesktop) {
        final notification = LocalNotification(
          identifier: 'alugplus_notif_$id',
          title: title,
          body: body,
        );
        await notification.show();
      } else if (_isMobile) {
        const androidDetails = AndroidNotificationDetails(
          'alugplus_rentals_channel',
          'Alertas de Aluguéis AlugPlus+',
          channelDescription:
              'Notificações de término de tempo e cobrança de acréscimo',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        const details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _mobilePlugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: details,
        );
      }
    } catch (e) {
      debugPrint('NotificationService dispatch warning: $e');
    }
  }
}
