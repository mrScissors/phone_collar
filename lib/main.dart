import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/notification_service.dart';
import 'services/local_db_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Request phone permission (for call log access)
  await requestCallLogPermission();

  // Initialize Firebase and notifications
  await Firebase.initializeApp();
  await NotificationService.initialize();
  final notificationService = NotificationService();
  await notificationService.setupNotifications();

  // Set up platform-specific notification initialization settings
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create and initialize the local database service instance
  final localDbService = LocalDbService();
  await localDbService.initialize();

  // Run the app with the dependency injected
  runApp(CallLogApp(localDbService: localDbService));
}

Future<void> requestCallLogPermission() async {
  if (!await Permission.phone.isGranted) {
    await Permission.phone.request();
  }
}
