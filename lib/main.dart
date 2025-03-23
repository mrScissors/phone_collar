import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/notification_service.dart';
import 'services/local_db_service.dart';
import 'auth/auth_service.dart';
import 'auth/splash_screen.dart';

/// A global key to reference the Navigator’s state from anywhere (e.g. MethodChannel).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// EventChannel for detecting calls in real time when the app is in the foreground.
const EventChannel eventChannel = EventChannel("com.example.phone_collar/incomingCallStream");

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up the MethodChannel callback BEFORE running the app,
  // so we can push the '/callScreen' from native side triggers.
  const MethodChannel channel = MethodChannel('com.example.phone_collar/call_screen');
  channel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'showCallScreen') {
      final String phoneNumber = call.arguments as String;
      // Push the call screen route
      navigatorKey.currentState?.pushNamed('/callScreen', arguments: phoneNumber);
    }
    return null;
  });

  // Request phone permission (for call logs, etc.)
  await requestCallLogPermission();

  // Initialize Firebase and notifications
  await Firebase.initializeApp();
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

    // If this app was launched by the CallFlutterService passing an extra,
    // check that extra and navigate to call UI if needed:
    WidgetsBinding.instance.addPostFrameCallback((_) => checkCallUIFlag());

    // Listen for incoming calls in real time:
    eventChannel.receiveBroadcastStream().listen((number) {
      setState(() => incomingNumber = number);

      // Push the named route for the CallScreen
      navigatorKey.currentState?.pushNamed('/callScreen', arguments: number);
    });
  }

  /// Checks if the Activity/Intent had "incoming_number" in the route arguments.
  void checkCallUIFlag() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      navigatorKey.currentState?.pushNamed('/callScreen', arguments: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Attach the global navigatorKey
      navigatorKey: navigatorKey,
      title: 'Call Log App',
      debugShowCheckedModeBanner: false,

      // Define routes, including /callScreen
      routes: {
        '/': (ctx) => SplashScreen(
          localDbService: widget.localDbService,
          authService: widget.authService,
        ),

        // Named route for the CallScreen
        '/callScreen': (ctx) {
          // Pull phoneNumber from pushNamed's arguments
          final phoneNumber = ModalRoute.of(ctx)?.settings.arguments as String? ?? 'Unknown';
          return CallScreen(
            phoneNumber: phoneNumber,
            localDbService: widget.localDbService,
          );
        },
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

/// The CallScreen widget, displayed on incoming calls.
class CallScreen extends StatefulWidget {
  final String phoneNumber;
  final LocalDbService localDbService; // local DB

  const CallScreen({
    Key? key,
    required this.phoneNumber,
    required this.localDbService,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String callerID = "Fetching...";

  @override
  void initState() {
    super.initState();
    fetchCallerID();
  }

  /// Look up the number in the local DB to find a display name
  Future<void> fetchCallerID() async {
    final callers = await widget.localDbService.searchContactsByNumber(widget.phoneNumber);
    final foundName = callers.isNotEmpty ? callers.first.name : null;
    setState(() {
      callerID = foundName ?? "Unknown Caller";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Incoming Call',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 10),
            Text(
              widget.phoneNumber, // Always show phone number
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 5),
            Text(
              callerID, // The fetched caller ID
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Accept call
                Navigator.pop(context);
              },
              child: const Text("Accept"),
            ),
            ElevatedButton(
              onPressed: () {
                // Decline call
                Navigator.pop(context);
              },
              child: const Text("Decline"),
            ),
          ],
        ),
      ),
    );
  }
}
