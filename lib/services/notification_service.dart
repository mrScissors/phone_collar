import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize iOS settings
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // Initialize settings for both platforms
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
        // Handle notification tap
        print('Notification clicked: ${notificationResponse.payload}');
      },
    );

    // Request permissions for iOS
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
  Future<void> requestNotificationPermissions() async {
    // For Android 13 and above (API level 33)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  // Call this method when your app starts
  Future<void> setupNotifications() async {
    await requestNotificationPermissions();
  }

  static Future<void> showIncomingCallNotification(String number) async {
    try {
      // Create the notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'incoming_call_channel',
        'Incoming Call',
        description: 'Notification for incoming call number',
        importance: Importance.max,
        playSound: true,
      );

      // Register the channel with the system
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Configure the notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'incoming_call_channel',
        'Incoming Call',
        channelDescription: 'Notification for incoming call number',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        playSound: true,
        ongoing: true,
        autoCancel: false,
        fullScreenIntent: true,  // Important for call notifications
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'incoming_call.aiff',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // Show the notification
      await flutterLocalNotificationsPlugin.show(
        0,  // Using a fixed ID, consider using a unique ID if needed
        'Incoming Call',
        'Incoming number: $number',
        notificationDetails,
        payload: 'incoming_call',
      );
    } catch (e) {
      print('Error showing notification: $e');
      throw e;  // Re-throw to help with debugging
    }
  }
}