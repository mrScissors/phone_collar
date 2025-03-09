import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:phone_collar/utils/search_name_formatter.dart';
import '../../../services/firebase_service.dart';
import '../../../services/call_log_service.dart';
import '../../models/caller.dart';
import '../../services/notification_service.dart';
import '../search_results_screen.dart';
import 'widgets/call_log_tile.dart';
import '../../call_event_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/local_db_service.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum SearchType { name, number }

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  _CallLogsScreenState createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  final CallLogService _callLogService = CallLogService();
  final FirebaseService _firebaseService = FirebaseService();
  final LocalDbService _localDbService = LocalDbService(); // Add local DB service
  final TextEditingController _searchController = TextEditingController();
  List<CallLogEntry> _callLogs = [];
  List<CallLogEntry> _filteredCallLogs = [];
  bool _isSearching = false;
  bool _isLoadingCallLogs = true;
  bool _isLoadingFirebase = true;
  bool _isSyncingContacts = false; // Flag for contact syncing state
  SearchType _searchType = SearchType.name;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _requestNotificationPermission();
    _fetchCallLogs();
    _setupCallEventListener();
    _initializeLocalDb();
    checkAndSyncContacts();
  }

  Future<void> checkAndSyncContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    int? lastSyncTime = prefs.getInt('lastSyncTime');
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    const int thresholdForResyncInMilliSeconds = 48 * 60 * 60 * 1000;

    if (lastSyncTime == null || (currentTime - lastSyncTime) > thresholdForResyncInMilliSeconds) {
      await syncContacts();
      await prefs.setInt('lastSyncTime', currentTime);
    }
  }

  Future<void> _initializeLocalDb() async {
    await _localDbService.initialize();
  }

  Future<void> _initializeFirebase() async {
    await _firebaseService.initializeWithCallersData();
    if (mounted) {
      setState(() {
        _isLoadingFirebase = false;
      });
    }
  }

  Future<void> _fetchCallLogs() async {
    final logs = await _callLogService.getCallLogs();
    if (mounted) {
      setState(() {
        _callLogs = logs;
        _filteredCallLogs = logs;
        _isLoadingCallLogs = false;
      });
    }
  }

  // New method to sync contacts from Firebase to local DB
  Future<void> syncContacts() async {
    if (_isSyncingContacts) return; // Prevent multiple syncs

    // Show loading dialog when starting sync
    showDialog(
      context: context,
      barrierDismissible: false, // User must wait for the sync to complete
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Syncing contacts...'),
                const SizedBox(height: 10),
                Text('Please wait while your contacts are being loaded',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        );
      },
    );

    setState(() {
      _isSyncingContacts = true;
    });
    await _initializeFirebase();

    try {
      _localDbService.clearLocalDb();
      final contacts = await _firebaseService.getAllContacts();

      await _localDbService.saveContacts(contacts);

      // Request contact permissions
      PermissionStatus permissionStatus = await Permission.contacts.status;
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.contacts.request();
        if (!permissionStatus.isGranted) {
          print('Contact permission denied');
          return null;
        }
      }

      Iterable<Contact> contactsLocal = await ContactsService.getContacts(withThumbnails: false);
      List<Caller> callersLocal = [];
      for (Contact contact in contactsLocal) {
        var searchName = formatSearchName(contact.displayName??'');
        var callerLocal = Caller(
          name: contact.displayName ?? 'Unknown',
          phoneNumbers: contact.phones!.map((item) => item.toString()).toList(),
          searchName: searchName
        );
        callersLocal.add(callerLocal);
      }
      await _localDbService.saveContacts(callersLocal);
      // Close the loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced ${contacts.length} contacts'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close the loading dialog even if there's an error
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync contacts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error syncing contacts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingContacts = false;
        });
      }
    }
  }

  void _setupCallEventListener() {
    CallEventChannel.incomingCallStream.listen((number) async {
      if (!mounted) return;

      try {
        // First check local database for faster lookup
        final localContact = await _localDbService.getContactByNumber(number);

        if (localContact != null) {
          NotificationService.showIncomingCallNotification(localContact.name);
          return;
        }

        /*
        // If not found locally, check Firebase
        final snapshot = await _firebaseService.searchByNumber(number);
        final displayName = snapshot?.isNotEmpty == true
            ? snapshot!.first.name
            : number ?? 'Unknown';

        NotificationService.showIncomingCallNotification(displayName);

         */
      } catch (e) {
        print('Error in call event listener: $e');
        if (mounted) {
          NotificationService.showIncomingCallNotification(number ?? 'Unknown');
        }
      }
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      // Request notification permission for Android 13+
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _firebaseService.initializeWithCallersData();
    await _fetchCallLogs();
  }

  void _onSearchChanged() async {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      setState(() {
        _filteredCallLogs = _callLogs;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    if (_searchType == SearchType.name) {
      await _searchByName(searchQuery);
    } else {
      await _searchByNumber(searchQuery);
    }
  }

  Future<void> _searchByName(String query) async {
    // First search in local database
    final localResults = await _localDbService.searchContactsByName(query);

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(results: localResults),
        ),
      );
    return;

/*
    // If no local results, search in Firebase
    final matchingCallers = await _firebaseService.searchByName(query);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(results: matchingCallers),
      ),
    );

 */
  }

  Future<void> _searchByNumber(String query) async {
    // First search in local database
    final localResults = await _localDbService.searchContactsByNumber(query);

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(results: localResults),
        ),
      );
    return;

/*
    // If no local results, search in Firebase
    final matchingCallers = await _firebaseService.searchByNumber(query);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(results: matchingCallers),
      ),
    );

 */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
        actions: [
          // Add the sync button in the app bar
          _isSyncingContacts
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          )
              : TextButton.icon(
            icon: const Icon(Icons.sync, color: Colors.white),
            label: const Text(
              'Sync Contacts',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: syncContacts,
          ),
        ],
        /*
        * actions: [
    // Add the sync button in the app bar
    _isSyncingContacts
        ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          )
        : TextButton.icon(
            icon: const Icon(Icons.sync, color: Colors.white),
            label: const Text(
              'Sync Contacts',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: syncContacts,
          ),
  ], */
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                SegmentedButton<SearchType>(
                  segments: const [
                    ButtonSegment<SearchType>(
                      value: SearchType.name,
                      label: Text('Search by Name'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment<SearchType>(
                      value: SearchType.number,
                      label: Text('Search by Number'),
                      icon: Icon(Icons.phone),
                    ),
                  ],
                  selected: {_searchType},
                  onSelectionChanged: (Set<SearchType> selection) {
                    setState(() {
                      _searchType = selection.first;
                      _searchController.clear();
                      _filteredCallLogs = _callLogs;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _searchType == SearchType.name
                        ? 'Enter name to search'
                        : 'Enter phone number to search',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _filteredCallLogs = _callLogs;
                          _isSearching = false;
                        });
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: _searchType == SearchType.number
                      ? TextInputType.phone
                      : TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _onSearchChanged();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingCallLogs) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading call logs...'),
          ],
        ),
      );
    }

    if (_callLogs.isEmpty) {
      return const Center(child: Text('No call logs found'));
    }

    if (_isSearching && _filteredCallLogs.isEmpty) {
      return Center(
        child: Text(
          _searchType == SearchType.name
              ? 'No calls found for this name'
              : 'No calls found for this number',
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredCallLogs.length,
      itemBuilder: (context, index) => CallLogTile(
        callLogEntry: _filteredCallLogs[index],
        localDbService: _localDbService, // Pass local DB service to the tile
      ),
    );
  }
}