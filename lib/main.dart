import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/notification_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await requestCallLogPermission();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  final notificationService = NotificationService();
  await notificationService.setupNotifications();
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(CallLogApp());
}

Future<void> requestCallLogPermission() async {
  if (!await Permission.phone.isGranted) {
    await Permission.phone.request();
  }
}