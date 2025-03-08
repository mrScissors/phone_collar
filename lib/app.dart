import 'package:flutter/material.dart';
import 'screens/call_logs/home.dart';

class CallLogApp extends StatelessWidget {
  const CallLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Call Log App',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const CallLogsScreen(),
    );
  }
}
