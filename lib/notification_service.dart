import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        print("Notification clicked!");
      },
    );
  }

  // 安排通知：在 scheduledTime 到达时提醒；Daily/Weekly/Monthly 为重复提醒（每天/每周/每月同一时间）
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String repeatType = 'None',
  }) async {
    try {
      final now = DateTime.now();
      if (repeatType == 'None' && scheduledTime.isBefore(now)) {
        print("⏰ 日程时间已过，跳过通知: $scheduledTime");
        return;
      }

      final tz.TZDateTime tzTime = tz.TZDateTime(
        tz.UTC,
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
        scheduledTime.second,
      );

      DateTimeComponents? matchComponents;
      switch (repeatType) {
        case 'Daily':
          matchComponents = DateTimeComponents.time;
          break;
        case 'Weekly':
          matchComponents = DateTimeComponents.dayOfWeekAndTime;
          break;
        case 'Monthly':
          matchComponents = DateTimeComponents.dayOfMonthAndTime;
          break;
        default:
          matchComponents = null;
      }

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'oppo_final_channel_99',
            'Pet Reminders',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            playSound: true,
            enableVibration: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
      );

      if (repeatType == 'None') {
        print("🎯 已安排单次提醒，触发时间: $scheduledTime");
      } else {
        print("🎯 已安排重复提醒 ($repeatType)，基准时间: $scheduledTime");
      }
    } catch (e) {
      print("❌ 安排通知失败: $e");
    }
  }
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Pet 疫苗提醒使用独立 id 区间，避免与 schedule 的 id 冲突
  static int petVaccineNotificationId(dynamic petID) {
    final id = int.tryParse(petID.toString());
    if (id != null) return 500000 + (id % 500000);
    return 500000 + (petID.hashCode.abs() % 500000);
  }

  /// Test: sends a notification in ~10 seconds. Use to verify notifications work.
  static Future<void> scheduleTestNotification() async {
    const testId = 888888;
    final in10Sec = DateTime.now().add(const Duration(seconds: 10));
    await scheduleNotification(
      id: testId,
      title: 'Test notification',
      body: 'If you see this, notifications are working! (sent 10 sec after tap)',
      scheduledTime: in10Sec,
      repeatType: 'None',
    );
    print("Test notification scheduled: will show in ~10 seconds");
  }
}
