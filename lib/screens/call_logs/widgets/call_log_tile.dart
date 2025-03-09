import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/caller.dart';
import '../../../services/local_db_service.dart';

class CallLogTile extends StatelessWidget {
  final CallLogEntry callLogEntry;
  final LocalDbService localDbService;

  const CallLogTile({
    super.key,
    required this.callLogEntry,
    required this.localDbService,
  });

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  void _showOptions(BuildContext context, String displayName, String phoneNumber) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder( // Add StatefulBuilder here
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView( // Add SingleChildScrollView
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  phoneNumber,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.call, color: Colors.green),
                  title: const Text('Call'),
                  onTap: () {
                    Navigator.pop(context);
                    _makePhoneCall(phoneNumber);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.message, color: Colors.blue),
                  title: const Text('Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _sendSMS(phoneNumber);
                  },
                ),
                FutureBuilder<List<CallLogEntry>>(  // Changed Iterable to List
                  future: fetchCallLogs(phoneNumber),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return ListTile(
                        leading: const Icon(Icons.error, color: Colors.red),
                        title: const Text('Error loading call logs'),
                        subtitle: Text(snapshot.error.toString()),
                      );
                    }

                    final calls = snapshot.data ?? [];

                    if (calls.isEmpty) {
                      return const ListTile(
                        leading: Icon(Icons.history, color: Colors.grey),
                        title: Text('No recent calls found'),
                      );
                    }

                    return ExpansionTile(
                      leading: const Icon(Icons.history, color: Colors.orange),
                      title: Text('Recent Calls (last 30 days) (${calls.length})'),
                      children: calls.map((call) => ListTile(
                        dense: true,
                        leading: Icon(_getCallTypeIcon(call.callType)),
                        title: Text(
                          '${call.duration} seconds',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          DateTime.fromMillisecondsSinceEpoch(call.timestamp ?? 0)
                              .toLocal()
                              .toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<CallLogEntry>> fetchCallLogs(String phoneNumber) async {
    try {
      // Normalize the phone number by removing any non-digit characters
      final normalizedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Get logs from the last 30 days
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final logs = await CallLog.query(
        number: normalizedNumber,
        dateFrom: thirtyDaysAgo.millisecondsSinceEpoch,
      );

      return logs.toList();
    } catch (e) {
      print('Error fetching call logs: $e');
      return [];
    }
  }

  IconData _getCallTypeIcon(CallType? callType) {
    switch (callType) {
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.incoming:
        return Icons.call_received;
      case CallType.missed:
        return Icons.call_missed;
      case CallType.rejected:
        return Icons.call_end;
      default:
        return Icons.call;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Caller?>(
      future: localDbService.getContactByNumber(callLogEntry.number ?? ''),
      builder: (context, snapshot) {
        String displayName;

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          try {
            displayName = snapshot.data!.name;
          } catch (e) {
            print('Error accessing caller data: $e');
            displayName = callLogEntry.number ?? 'Unknown1';
          }
        } else {
          displayName = callLogEntry.number ?? 'Unknown2';
        }
        return ListTile(
          title: Text(displayName),
          subtitle: Text(
            'Type: ${callLogEntry.callType.toString().split('.').last} | '
                'Date: ${DateTime.fromMillisecondsSinceEpoch(callLogEntry.timestamp ?? 0).toLocal()}',
          ),
          leading: Icon(
            _getCallTypeIcon(callLogEntry.callType),
            color: callLogEntry.callType == CallType.missed ? Colors.red : null,
          ),
          onTap: () => _showOptions(
            context,
            displayName,
            callLogEntry.number ?? 'Unknown3',
          ),
        );
      },
    );
  }

}