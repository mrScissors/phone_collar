
// splash_screen.dart
import 'package:flutter/material.dart';
import 'package:phone_collar/services/firebase_service.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import '../app.dart';
import '../services/local_db_service.dart';

class SplashScreen extends StatefulWidget {
  final LocalDbService localDbService;
  final FirebaseService firebaseService;
  final AuthService authService;

  const SplashScreen({
    Key? key,
    required this.localDbService,
    required this.authService, required this.firebaseService,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Wait for the auth service initialization to complete.
    await widget.authService.initialize();

    if (!mounted) return;

    _checkLoginStatus();
  }

  void _checkLoginStatus() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CallLogApp(
          localDbService: widget.localDbService,
          firebaseService: widget.firebaseService,
          authService: widget.authService,
        ),
      ),
    );
    /*
    // Check if user is already logged in
    final currentUser = widget.authService.currentUser;

    if (currentUser != null) {
      // User is logged in, navigate to main app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CallLogApp(
            localDbService: widget.localDbService,
            authService: widget.authService,
          ),
        ),
      );
    } else {
      // User is not logged in, navigate to the login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            authService: widget.authService,
            localDbService: widget.localDbService,
          ),
        ),
      );
    }

     */
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
