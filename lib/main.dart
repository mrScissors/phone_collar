import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/notification_service.dart';
import 'services/local_db_service.dart';
import 'auth/auth_service.dart';
import 'auth/splash_screen.dart';

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
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create and initialize the local database service instance
  final localDbService = LocalDbService();
  await localDbService.initialize();

  // Create authentication service
  final authService = AuthService();

  // Run the app with the dependencies injected
  runApp(MyApp(
    localDbService: localDbService,
    authService: authService,
  ));
}

Future<void> requestCallLogPermission() async {
  if (!await Permission.phone.isGranted) {
    await Permission.phone.request();
  }
}

class MyApp extends StatelessWidget {
  final LocalDbService localDbService;
  final AuthService authService;

  const MyApp({
    Key? key,
    required this.localDbService,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Log App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        // You can also set a color scheme for Material 3:
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange,
          onPrimary: Colors.black,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black, backgroundColor: Colors.orange,
          ),
        ),
        useMaterial3: true,
      ),
      home: SplashScreen(
        localDbService: localDbService,
        authService: authService,
      ),
    );
  }
}
