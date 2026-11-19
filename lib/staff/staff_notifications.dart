import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class StaffNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _setup;
  int _nextId = 0;

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _initialize() async {
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_upload'),
    ));
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      await (_setup ??= _initialize());
      return await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      _setup = null;
      return false;
    }
  }

  Future<bool> showSuccess(String product, String attachment) async {
    if (!supported) return false;
    try {
      await (_setup ??= _initialize());
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (await android?.areNotificationsEnabled() != true) return false;
      await _plugin.show(
        _nextId++,
        'Arquivo enviado com sucesso',
        '$attachment · $product',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'envios_cardapio',
            'Envios do cardápio',
            channelDescription: 'Confirmações de envio de fotos e fichas técnicas.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      return true;
    } catch (_) {
      _setup = null;
      return false;
    }
  }
}
