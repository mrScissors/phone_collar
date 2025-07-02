import 'package:flutter/material.dart';
import 'package:phone_collar/auth/auth_service.dart';
import 'package:phone_collar/services/firebase_service.dart';
import 'screens/home/home.dart';
import 'services/local_db_service.dart';

class CallLogApp extends StatelessWidget {
  final LocalDbService localDbService;
  final FirebaseService firebaseService;
  final AuthService authService;
  const CallLogApp({Key? key, required this.localDbService, required this.authService, required this.firebaseService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Call Log App',
      home: HomeScreen(localDbService: localDbService, firebaseService: firebaseService, authService: authService),
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
