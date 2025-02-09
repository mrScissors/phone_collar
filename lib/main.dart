import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() => runApp(CallLogApp());

class CallLogApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Log App',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: CallLogsScreen(),
    );
  }
}

class CallLogsScreen extends StatefulWidget {
  @override
  _CallLogsScreenState createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  List<CallLogEntry> _callLogs = [];
  Database? _database;

  @override
  void initState() {
    super.initState();
    _initDatabase().then((_) {
      _fetchCallLogs();
    });
  }

  /// Initialize the SQLite database.
  Future<void> _initDatabase() async {
    // Construct the path to the database.
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'caller_db.db');

    // Open (or create) the database.
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        // Create the 'callers' table
        await db.execute(
          "CREATE TABLE callers (id INTEGER PRIMARY KEY, phone TEXT UNIQUE, name TEXT)",
        );

        // Insert some sample data.
        // Replace these with your actual custom caller data.
        await db.insert('callers', {'phone': '9860669446', 'name': 'Aai'});
        await db.insert('callers', {'phone': '+1987654321', 'name': 'Bob'});
      },
    );
  }

  /// Fetch call logs from the device.
  Future<void> _fetchCallLogs() async {
    // Depending on your implementation you may need to check/request permissions here.
    Iterable<CallLogEntry> entries = await CallLog.get();
    setState(() {
      _callLogs = entries.toList();
    });
  }

  /// Given a phone number, look up the friendly name in your custom database.
  Future<String> _getCallerName(String? phoneNumber) async {
    if (phoneNumber == null || _database == null) {
      return 'Unknown';
    }

    phoneNumber = phoneNumber.substring(phoneNumber.length < 10 ? 0 : phoneNumber.length - 10);
    // Query the database for a matching phone number.
    List<Map> results = await _database!.query(
      'callers',
      where: 'phone LIKE ?',
      whereArgs: ['%$phoneNumber'],  // The % means "match anything before these digits"
    );

    if (results.isNotEmpty) {
      return results.first['name'] as String;
    }
    // Return the number itself if no match is found.
    return phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Call Logs'),
      ),
      body: _callLogs.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _callLogs.length,
        itemBuilder: (context, index) {
          final entry = _callLogs[index];
          return FutureBuilder(
            future: _getCallerName(entry.number),
            builder: (context, snapshot) {
              String displayName =
              snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData
                  ? snapshot.data as String
                  : entry.number ?? 'Unknown';
              return ListTile(
                title: Text(displayName),
                subtitle: Text(
                  'Type: ${entry.callType.toString().split('.').last} | '
                      'Date: ${DateTime.fromMillisecondsSinceEpoch(entry.timestamp!).toLocal()}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
