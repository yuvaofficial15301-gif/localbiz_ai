import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../shared/models/models.dart';
import '../../features/inventory/inventory_service.dart';
import 'settings_service.dart';
import '../utils/money.dart';

/// Local notifications only; nothing leaves the device.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(init);
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false; // notifications are optional; never block the app
    }
  }

  Future<void> show(int id, String title, String body) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'localbiz_alerts',
        'Shop alerts',
        channelDescription: 'Low stock, expiry and backup reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }
}

/// Decides which alerts are due; at most one notification per kind per day.
class AlertsService {
  final SettingsService settings;
  final InventoryService inventory;
  final NotificationService notifier;
  AlertsService(this.settings, this.inventory, this.notifier);

  Future<bool> _dueToday(String key) async {
    final today = nowIso().substring(0, 10);
    final last = await settings.get(key);
    if (last == today) return false;
    await settings.set(key, today);
    return true;
  }

  Future<void> check(Session s) async {
    await notifier.init();
    if (await settings.getBool('notif_low_stock', def: true)) {
      try {
        final low = await inventory.lowStock(s);
        if (low.isNotEmpty && await _dueToday('notified_low_stock')) {
          final names = low.take(5).map((e) => e.name).join(', ');
          await notifier.show(1, 'Low stock (${low.length})', names);
        }
      } catch (_) {}
    }
    if (await settings.getBool('notif_expiry', def: true)) {
      try {
        final days = await settings.getInt('expiry_warn_days', def: 14);
        final exp = await inventory.expiringSoon(s, days);
        if (exp.isNotEmpty && await _dueToday('notified_expiry')) {
          final names = exp.take(5).map((e) => e.name).join(', ');
          await notifier.show(2, 'Expiring soon (${exp.length})', names);
        }
      } catch (_) {}
    }
    if (s.can('backup_restore') &&
        await settings.getBool('notif_backup', def: true)) {
      final every = await settings.getInt('backup_reminder_days', def: 7);
      final last = await settings.get('last_backup');
      var overdue = last == null;
      if (last != null) {
        final dt = DateTime.tryParse(last);
        overdue = dt == null || AppClock.now().difference(dt).inDays >= every;
      }
      if (overdue && await _dueToday('notified_backup')) {
        await notifier.show(3, 'Backup reminder',
            'Back up your shop data. If your phone is lost or damaged, local data may be lost.');
      }
    }
  }
}
