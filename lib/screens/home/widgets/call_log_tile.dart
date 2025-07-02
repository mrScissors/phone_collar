import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:phone_collar/services/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/caller.dart';
import '../../../services/local_db_service.dart';
import '../../../utils/search_name_formatter.dart';
import 'save_contact_form_dialog.dart';

class CallLogTile extends StatelessWidget {
  final CallLogEntry callLogEntry;
  final LocalDbService localDbService;
  final FirebaseService firebaseService;
  final VoidCallback? onRefreshNeeded;

  const CallLogTile({
    super.key,
    required this.callLogEntry,
    required this.localDbService, required this.firebaseService, this.onRefreshNeeded,
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary; // Orange color from theme
    final onBackgroundColor = theme.colorScheme.onBackground;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.background, // Use theme background color (likely black)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: theme.textTheme.titleLarge?.copyWith(color: onBackgroundColor),
                      ),
                    ),
                    if (displayName == phoneNumber)
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context); // Close bottom sheet
                          bool contactSaved = await showAddContactForm(context: context, localDbService: localDbService, firebaseService:  firebaseService, prefillNumber: phoneNumber);
                          if (contactSaved) {
                            onRefreshNeeded?.call(); // Only refresh if contact was actually saved
                          }
                        },
                        icon: Icon(Icons.person_add, color: primaryColor),
                        label: Text("Save", style: TextStyle(color: primaryColor)),
                      ),
                  ],
                ),

                Text(
                  phoneNumber,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onBackgroundColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.call, color: primaryColor),
                  title: Text('Call', style: TextStyle(color: onBackgroundColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _makePhoneCall(phoneNumber);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.message, color: primaryColor),
                  title: Text('Message', style: TextStyle(color: onBackgroundColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _sendSMS(phoneNumber);
                  },
                ),
                FutureBuilder<List<CallLogEntry>>(
                  future: fetchCallLogs(phoneNumber),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(color: primaryColor),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return ListTile(
                        leading: Icon(Icons.error, color: theme.colorScheme.error),
                        title: Text('Error loading call logs', style: TextStyle(color: onBackgroundColor)),
                        subtitle: Text(snapshot.error.toString(), style: TextStyle(color: onBackgroundColor.withOpacity(0.6))),
                      );
                    }

                    final calls = snapshot.data ?? [];

                    if (calls.isEmpty) {
                      return ListTile(
                        leading: Icon(Icons.history, color: onBackgroundColor.withOpacity(0.6)),
                        title: Text('No recent calls found', style: TextStyle(color: onBackgroundColor)),
                      );
                    }

                    return ExpansionTile(
                      leading: Icon(Icons.history, color: primaryColor),
                      title: Text('Recent Calls (last 30 days) (${calls.length})',
                          style: TextStyle(color: onBackgroundColor)),
                      collapsedIconColor: primaryColor,
                      iconColor: primaryColor,
                      children: calls.map((call) => ListTile(
                        dense: true,
                        leading: Icon(_getCallTypeIcon(call.callType),
                            color: call.callType == CallType.missed ? theme.colorScheme.error : primaryColor),
                        title: Text(
                          '${call.duration} seconds',
                          style: TextStyle(fontSize: 14, color: onBackgroundColor),
                        ),
                        subtitle: Text(
                          DateTime.fromMillisecondsSinceEpoch(call.timestamp ?? 0)
                              .toLocal()
                              .toString(),
                          style: TextStyle(fontSize: 12, color: onBackgroundColor.withOpacity(0.6)),
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
    // No changes needed here
    try {
      final normalizedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
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
    // No changes needed here
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary; // Orange from theme
    final onBackgroundColor = theme.colorScheme.onBackground;

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
          title: Text(displayName, style: TextStyle(color: onBackgroundColor)),
          subtitle: Text(
            'Type: ${callLogEntry.callType.toString().split('.').last} | '
                'Date: ${DateTime.fromMillisecondsSinceEpoch(callLogEntry.timestamp ?? 0).toLocal()}',
            style: TextStyle(color: onBackgroundColor.withOpacity(0.6)),
          ),
          leading: Icon(
            _getCallTypeIcon(callLogEntry.callType),
            color: callLogEntry.callType == CallType.missed ? theme.colorScheme.error : primaryColor,
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