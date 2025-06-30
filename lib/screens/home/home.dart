import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_collar/auth/auth_service.dart';
import 'package:phone_collar/services/local_db_service.dart';
import 'callLogsAndSearch.dart';
import 't9dialer.dart';

class HomeScreen extends StatefulWidget {
  final LocalDbService localDbService;
  final AuthService authService;
  const HomeScreen({Key? key, required this.localDbService, required this.authService}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Schedule notification permission request after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestNotificationPermission();
    });
    requestContactsPermission();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      T9DialerScreen(localDbService: widget.localDbService),
      CallLogsScreen(localDbService: widget.localDbService, authService: widget.authService,)
    ];
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad),
            label: 'Dialer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Logs & Search',
          ),
        ],
      ),
    );
  }

  Future<void> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> requestContactsPermission() async {
    PermissionStatus permissionStatus = await Permission.contacts.status;
    if (!permissionStatus.isGranted) {
      permissionStatus = await Permission.contacts.request();
      if (!permissionStatus.isGranted) {
        print('Contact permission denied');
        return;
      }
    }
  }
}