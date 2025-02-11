import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import '../../../services/firebase_service.dart';
import '../../../services/call_log_service.dart';
import 'widgets/call_log_tile.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  _CallLogsScreenState createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  final CallLogService _callLogService = CallLogService();
  final FirebaseService _firebaseService = FirebaseService();
  List<CallLogEntry> _callLogs = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _firebaseService.initializeWithSampleData();
    await _fetchCallLogs();
  }

  Future<void> _fetchCallLogs() async {
    final logs = await _callLogService.getCallLogs();
    setState(() {
      _callLogs = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
      ),
      body: _callLogs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _callLogs.length,
        itemBuilder: (context, index) => CallLogTile(
          callLogEntry: _callLogs[index],
          firebaseService: _firebaseService,
        ),
      ),
    );
  }
}