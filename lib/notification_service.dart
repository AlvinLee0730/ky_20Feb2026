import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  /// Initialize notifications
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);

    if (Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestExactAlarmsPermission();
        await androidPlugin.requestNotificationsPermission();
      }
    }
  }

  /// Cancel a notification by ID
  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  /// Vaccine reminder 3 days before expiry at 9:00 AM
  static Future<void> scheduleVaccineReminder({
    required String petId,  // UUID string
    required String petName,
    required DateTime expiryDate,
  }) async {
    final reminderDate = expiryDate.subtract(const Duration(days: 3));
    final reminderTime = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      9,
      0,
    );

    final now = tz.TZDateTime.now(tz.local);
    if (reminderTime.isBefore(now)) {
      print('Reminder time has passed, skipping schedule for pet: $petId');
      return;
    }

    final int id = petId.hashCode.abs();  // UUID -> int

    try {
      await _notifications.zonedSchedule(
        id,
        'Vaccine Reminder - $petName',
        'Vaccine will expire on ${DateFormat('yyyy-MM-dd').format(expiryDate)}. Please plan ahead! (Reminder 3 days before)',
        reminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vaccine_channel',
            'Vaccine Reminders',
            channelDescription: '3-day prior reminders for pet vaccines',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'vaccine:$petId',
      );
      print('Vaccine reminder scheduled - petId: $petId, id: $id, time: $reminderTime');
    } catch (e) {
      print('Failed to schedule vaccine reminder: $e');
      rethrow; // let caller catch
    }
  }

  static Future<void> scheduleEventReminder({
    required String scheduleId,
    required String title,
    required String? description,
    required DateTime startDateTime,
    required String repeatType,
  }) async {
    final reminderTime = tz.TZDateTime.from(
      startDateTime.subtract(const Duration(minutes: 15)),
      tz.local,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = reminderTime;

    // 先取消舊的（避免重複或舊的卡住）
    final int notificationId = scheduleId.hashCode.abs();
    await _notifications.cancel(notificationId);

    if (repeatType == 'None') {
      // 一次性：如果已經過了，就不排
      if (scheduledTime.isBefore(now)) {
        print('Reminder time passed for one-time: $scheduleId');
        return;
      }
    } else {
      // Repeating：調整到下一個未來時間
      while (scheduledTime.isBefore(now) || scheduledTime == now) {
        if (repeatType == 'Daily') {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        } else if (repeatType == 'Weekly') {
          scheduledTime = scheduledTime.add(const Duration(days: 7));
        } else if (repeatType == 'Monthly') {
          // Monthly：加一個月，處理日期溢位（e.g. 31號 -> 下個月變 30/28/29）
          int nextMonth = scheduledTime.month + 1;
          int nextYear = scheduledTime.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          try {
            scheduledTime = tz.TZDateTime(
              tz.local,
              nextYear,
              nextMonth,
              scheduledTime.day,
              scheduledTime.hour,
              scheduledTime.minute,
            );
          } catch (e) {
            // 日不存在 → 取該月最後一天
            final daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
            scheduledTime = tz.TZDateTime(
              tz.local,
              nextYear,
              nextMonth,
              daysInMonth,
              scheduledTime.hour,
              scheduledTime.minute,
            );
          }
        }
      }
    }

    DateTimeComponents? matchComponent;
    if (repeatType == 'Daily') {
      matchComponent = DateTimeComponents.time;
    } else if (repeatType == 'Weekly') {
      matchComponent = DateTimeComponents.dayOfWeekAndTime;
    } else if (repeatType == 'Monthly') {
      matchComponent = DateTimeComponents.dayOfMonthAndTime;
    }

    final formattedStart = DateFormat('yyyy-MM-dd HH:mm').format(startDateTime);
    final message = description != null && description.isNotEmpty
        ? 'Event: $description\nStarts at: $formattedStart (15 min before)'
        : 'Event: $title\nStarts at: $formattedStart (15 min before)';

    try {
      await _notifications.zonedSchedule(
        notificationId,
        title,
        message,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'schedule_reminder_channel',
            'Schedule Reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponent,  // 只在 repeating 時用
        payload: 'schedule:$scheduleId',
      );
      print('Scheduled $repeatType reminder - id: $notificationId | next: $scheduledTime');
    } catch (e) {
      print('Failed to schedule: $e');
    }
  }

  /// 在 app 啟動、或 background 時呼叫，重新排所有 repeating 的下一次
  static Future<void> refreshRepeatingReminders() async {
    try {
      final response = await Supabase.instance.client
          .from('schedule')
          .select()
          .inFilter('repeatType', ['Daily', 'Weekly', 'Monthly']);

      for (var row in response) {
        final scheduleId = row['scheduleID'] as String;
        final dateStr = row['date'] as String;
        final timeStr = row['startTime'] as String;
        final startDateTime = DateTime.parse('$dateStr $timeStr');

        await scheduleEventReminder(
          scheduleId: scheduleId,
          title: row['title'] as String,
          description: row['description'] as String?,
          startDateTime: startDateTime,
          repeatType: row['repeatType'] as String,
        );
      }
      print('Refreshed ${response.length} repeating reminders');
    } catch (e) {
      print('Refresh repeating failed: $e');
    }
  }

  /// Test: Show notification immediately
  static Future<void> testShowNotification() async {
    try {
      await showSimpleNotification(
        id: 9999,
        title: "Immediate Test Notification",
        body: "This notification should appear immediately to verify plugin functionality.",
      );
      print('Immediate test notification sent successfully');
    } catch (e) {
      print('Failed to send immediate test notification: $e');
    }
  }

  /// Test: Schedule notification 30 seconds later
  static Future<void> testScheduledNotification() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(const Duration(seconds: 30));

      final int testId = 10000;

      await _notifications.zonedSchedule(
        testId,
        "Test Notification in 30 Seconds",
        "If this appears after 30 seconds, scheduled notifications are working correctly.",
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Channel',
            channelDescription: 'For development testing',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('30-second test notification scheduled, ID: $testId');
    } catch (e) {
      print('Failed to schedule 30-second test notification: $e');
    }
  }

  /// Show simple notification immediately
  static Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'general_test',
      'General Test',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}