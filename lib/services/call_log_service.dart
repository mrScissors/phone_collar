import 'package:call_log/call_log.dart';

class CallLogService {
  Future<List<CallLogEntry>> getCallLogs() async {
    // Here you might want to add permission checking logic
    final Iterable<CallLogEntry> entries = await CallLog.get();
    return entries.toList();
  }
}