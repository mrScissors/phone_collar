import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import '../../../services/firebase_service.dart';

class CallLogTile extends StatelessWidget {
  final CallLogEntry callLogEntry;
  final FirebaseService firebaseService;

  const CallLogTile({
    super.key,
    required this.callLogEntry,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: firebaseService.getCallerName(callLogEntry.number),
      builder: (context, snapshot) {
        String displayName =
        snapshot.connectionState == ConnectionState.done && snapshot.hasData
            ? snapshot.data!
            : callLogEntry.number ?? 'Unknown';

        return ListTile(
          title: Text(displayName),
          subtitle: Text(
            'Type: ${callLogEntry.callType.toString().split('.').last} | '
                'Date: ${DateTime.fromMillisecondsSinceEpoch(callLogEntry.timestamp!).toLocal()}',
          ),
        );
      },
    );
  }
}