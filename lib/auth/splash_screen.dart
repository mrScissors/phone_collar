// splash_screen.dart
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import '../app.dart';
import '../services/local_db_service.dart';

class SplashScreen extends StatefulWidget {
  final LocalDbService localDbService;
  final AuthService authService;

  const SplashScreen({
    Key? key,
    required this.localDbService,
    required this.authService,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Check if user is already logged in
    final currentUser = widget.authService.currentUser;

    if (currentUser != null) {
      // User is logged in, navigate to main app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CallLogApp(localDbService: widget.localDbService),
        ),
      );
    } else {
      // User is not logged in, navigate to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            authService: widget.authService,
            localDbService: widget.localDbService,
          ),
        ),
      );
    }
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