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

  // 1. 安排通知
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String repeatType = 'None',
  }) async {
    try {
      // 1. 直接获取当前本地时间，往后加 10 秒
      final now = DateTime.now();
      final testTime = now.add(const Duration(seconds: 10));

      // 2. ⭐ 关键修复：强制使用 UTC 格式但填入本地数值
      // 这样插件就会在本地时钟走到这个点时直接触发，不经过时区转换
      final tz.TZDateTime tzTime = tz.TZDateTime(
        tz.UTC, // 强制声明为 UTC，避免被时区库二次转换
        testTime.year,
        testTime.month,
        testTime.day,
        testTime.hour,
        testTime.minute,
        testTime.second,
      );

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
      );

      print("🎯 最终强制触发时间: $tzTime");
    } catch (e) {
      print("❌ 安排通知失败: $e");
    }
  }
  // 2. ⭐ 补上这个缺失的方法
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}