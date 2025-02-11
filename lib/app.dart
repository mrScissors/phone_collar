import 'package:flutter/material.dart';
import 'screens/call_logs/call_logs_screen.dart';

class CallLogApp extends StatelessWidget {
  const CallLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Log App',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const CallLogsScreen(),
    );
  }
}
