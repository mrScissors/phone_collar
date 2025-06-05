import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_collar/callHandler.dart';
import 'package:phone_collar/utils/phone_number_formatter.dart';
import 'services/notification_service.dart';
import 'services/local_db_service.dart';
import 'auth/auth_service.dart';
import 'auth/splash_screen.dart';
import 'package:firebase_database/firebase_database.dart';


const MethodChannel _channel = MethodChannel('caller_id_channel');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request phone permission (for call logs, etc.)
  await requestCallLogPermission();

  // Initialize Firebase and notifications
  await Firebase.initializeApp();
  /*
  FirebaseDatabase database = FirebaseDatabase.instance;
  database.setPersistenceEnabled(true);
  // (optional) bump cache if you want more than the default 10 MB
  database.setPersistenceCacheSizeBytes(100 * 1024 * 1024);

   */

  await NotificationService.initialize();
  final notificationService = NotificationService();
  await notificationService.setupNotifications();

  // Set up local notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Initialize local DB
  final localDbService = LocalDbService();
  await localDbService.initialize();
  final callHandler = CallHandler();
  callHandler.setupMethodChannelHandler();
  CallHandler.initializeLocalDbService(localDbService);

  _channel.setMethodCallHandler((call) async {
    print('Method channel received call: ${call.method}');
    print('Arguments: ${call.arguments}');

    Future<String?> lookupNameFromDatabase(String number) async {
      print('Database lookup for number: $number');
      var contacts = await localDbService.searchContactsByNumber(number);
      if (contacts.isNotEmpty){
        return contacts.first.name;
      }

      return "Unknown number: ($number)";
    }

    if (call.method == "lookupCallerId") {
      final String phoneNumber = call.arguments as String;
      print('Looking up caller ID for: $phoneNumber');

      // Query your database
      String? name = await lookupNameFromDatabase(phoneNumber);
      print('Found name: $name');

      return name ?? "Unknown Contact";  // Return a more descriptive fallback
    }

    print('Method not implemented: ${call.method}');
    throw PlatformException(code: 'NOT_IMPLEMENTED', message: 'Method ${call.method} not implemented');
  });



  // Create authentication service
  final authService = AuthService();

  // Run the app
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

/// Root widget of the app.
class MyApp extends StatefulWidget {
  final LocalDbService localDbService;
  final AuthService authService;

  const MyApp({
    Key? key,
    required this.localDbService,
    required this.authService,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Holds the state of the root widget, sets up MaterialApp, etc.
class _MyAppState extends State<MyApp> {
  String? incomingNumber;

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Attach the global navigatorKey
      title: 'Call Log App',
      debugShowCheckedModeBanner: false,

      // Define routes, including /callScreen
      routes: {
        '/': (ctx) => SplashScreen(
          localDbService: widget.localDbService,
          authService: widget.authService,
        ),
      },

      theme: ThemeData(
        primarySwatch: Colors.orange,
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
    );
  }
}


