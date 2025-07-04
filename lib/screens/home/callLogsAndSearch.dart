import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:phone_collar/utils/phone_number_formatter.dart';
import 'package:phone_collar/utils/search_name_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // <-- Replace old import here
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

import '../../../services/firebase_service.dart';
import '../../../services/call_log_service.dart';
import '../../../services/local_db_service.dart';
import '../../auth/auth_service.dart';
import '../../auth/login_screen.dart';
import '../../models/caller.dart';
import 'widgets/call_log_tile.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'widgets/save_contact_form_dialog.dart';

enum SearchType { name, number }

class CallLogsScreen extends StatefulWidget {
  final LocalDbService localDbService;
  final FirebaseService firebaseService;
  final AuthService authService;
  const CallLogsScreen({Key? key, required this.localDbService, required this.authService, required this.firebaseService}) : super(key: key);

  @override
  _CallLogsScreenState createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> with WidgetsBindingObserver {
  final CallLogService _callLogService = CallLogService();
  final TextEditingController _searchController = TextEditingController();

  List<CallLogEntry> _callLogs = [];
  List<CallLogEntry> _filteredCallLogs = [];
  List<Caller> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingCallLogs = true;
  bool _isLoadingFirebase = true;
  bool _isSyncingContacts = false; // Flag for contact syncing state

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer for lifecycle changes
    _initializeNotifications();
    _fetchCallLogs();
    _initializeLocalDb();
    checkAndSyncContacts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _searchController.dispose();
    super.dispose();
  }

  // Listen for lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the call logs when the app comes back to the foreground
      _fetchCallLogs();
    }
  }

  Future<void> checkAndSyncContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? lastSyncTime = prefs.getInt('lastSyncTime');
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    const int thresholdForResyncInMilliSeconds = 48 * 60 * 60 * 1000;

    if (lastSyncTime == null ||
        (currentTime - lastSyncTime) > thresholdForResyncInMilliSeconds) {
      await syncContacts();
      await prefs.setInt('lastSyncTime', currentTime);
    }
  }

  Future<void> _initializeLocalDb() async {
    await widget.localDbService.initialize();
  }

  Future<bool> _initializeFirebase() async {
    await widget.firebaseService.initializeWithCallersData();
    if (mounted) {
      setState(() {
        _isLoadingFirebase = false;
      });
      return true;
    }
    return false;
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

  /// -------------------------------
  /// SYNC CONTACTS USING flutter_contacts
  /// -------------------------------
  Future<void> syncContacts() async {
    if (_isSyncingContacts) return; // Prevent multiple syncs

    setState(() {
      _isSyncingContacts = true;
    });

    try {
      bool isMounted = await _initializeFirebase();

      // Request permission for reading contacts
      bool hasPermission = await FlutterContacts.requestPermission(readonly: false);
/*
      if (!hasPermission) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Permission Denied"),
              content: const Text("We need contact permission to sync your contacts."),
            ),
          );
        }

        return; // Exit sync
      }
*/
      // Clear local DB first
      await widget.localDbService.clearLocalDb();
      List<Contact> contactsLocal = [];
      /*
      // Retrieve contacts with phone numbers
      List<Contact> contactsLocal =
      await FlutterContacts.getContacts(withProperties: true);

       */

      List<Caller> callers = [];

      for (Contact contact in contactsLocal) {
        final displayName = contact.displayName.isEmpty
            ? 'Unknown'
            : contact.displayName;

        final phoneNumbers = contact.phones
            .map((phone) => formatPhoneNumber(phone.number))
            .where((p) => p.trim().isNotEmpty)
            .toList();

        var searchName = formatSearchName(displayName);

        var callerLocal = Caller(
            name: displayName,
            phoneNumbers: phoneNumbers,
            searchName: searchName,
            employeeName: 'PhoneContact',
            location: '',
            date: DateTime(2000,1,1)
        );

        callers.add(callerLocal);
      }

      // Fetch any server contacts from Firebase and add them in
      final (success, contacts) =
      await widget.firebaseService.getAllContacts(context: context);

      callers.addAll(contacts);

      // Save all contacts to the local database
      await widget.localDbService.saveContacts(callers);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced ${contacts.length} contacts'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
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

  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _initializeData() async {
    await widget.firebaseService.initializeWithCallersData();
    await _fetchCallLogs();
  }

  void _onSearchChanged() async {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    await searchByNameOrNumber(searchQuery);
  }

  Future<void> searchByNameOrNumber(String query) async {
    List<Caller> localResults =
    await widget.localDbService.searchContactsByName(query);
    if (!containsAlphabet(query)) {
      final localResultsNumber =
      await widget.localDbService.searchContactsByNumber(query);
      localResults.addAll(localResultsNumber);
    }
    setState(() {
      _searchResults = localResults;
    });
  }

  // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Helper method to check if date should be displayed
  bool _shouldShowDate(DateTime date) {
    return date.isAfter(DateTime(2000, 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
        backgroundColor: Theme.of(context).colorScheme.primary, // Orange background
        foregroundColor: Theme.of(context).colorScheme.onPrimary, // Text color
        actions: [
          _isSyncingContacts
              ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary, // Black color
                ),
              ),
            ),
          )
              : TextButton.icon(
            icon: Icon(Icons.sync, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(
              'Sync Contacts',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            onPressed: () => syncContacts(),
          ),
          // Three dot menu for additional options like Logout.
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onPrimary),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.power_settings_new, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter name or number to search',
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                      _filteredCallLogs = _callLogs;
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                _onSearchChanged();
              },
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showAddContactForm(
              context: context,
              localDbService: widget.localDbService,
              firebaseService: widget.firebaseService
          );
        },
        tooltip: 'Add Contact',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _makePhoneCall(List<String> numbers) async {
    if (numbers.isEmpty) return;
    if (numbers.length == 1) {
      final Uri launchUri = Uri(scheme: 'tel', path: numbers.first);
      await launchUrl(launchUri);
    } else {
      final selectedNumber = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Select Number to Call',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: numbers.map((number) {
                return ListTile(
                  title: Text(number),
                  onTap: () => Navigator.of(context).pop(number),
                );
              }).toList(),
            ),
          );
        },
      );
      if (selectedNumber != null) {
        final Uri launchUri = Uri(scheme: 'tel', path: selectedNumber);
        await launchUrl(launchUri);
      }
    }
  }

  void _sendMessage(List<String> numbers) async {
    if (numbers.isEmpty) return;
    if (numbers.length == 1) {
      final Uri launchUri = Uri(scheme: 'sms', path: numbers.first);
      await launchUrl(launchUri);
    } else {
      final selectedNumber = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Select Number to Message',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: numbers.map((number) {
                return ListTile(
                  title: Text(number),
                  onTap: () => Navigator.of(context).pop(number),
                );
              }).toList(),
            ),
          );
        },
      );
      if (selectedNumber != null) {
        final Uri launchUri = Uri(scheme: 'sms', path: selectedNumber);
        await launchUrl(launchUri);
      }
    }
  }


  Widget _buildBody() {
    if (_isSearching) {
      if (_searchResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No contact found for "${_searchController.text}"',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text('Would you like to:'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _makePhoneCall([
                      !containsAlphabet(_searchController.text)
                          ? _searchController.text
                          : ''
                    ]),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _sendMessage([_searchController.text]),
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await showAddContactForm(
                      context: context,
                      localDbService: widget.localDbService,
                      firebaseService: widget.firebaseService,
                      prefillNumber: _searchController.text
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        );
      } else {
        return ListView.builder(
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final caller = _searchResults[index];
            final List<String> numbers = caller.phoneNumbers.where((number) => number.trim().isNotEmpty).toList();

            // Build additional info widgets
            List<Widget> additionalInfo = [];

            // Add location if not empty
            if (caller.location.isNotEmpty) {
              additionalInfo.add(
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          caller.location,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Add date if it's after January 1, 2000
            if (_shouldShowDate(caller.date)) {
              additionalInfo.add(
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(caller.date),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Add employee name if not empty
            if (caller.employeeName.isNotEmpty && caller.employeeName != 'PhoneContact') {
              additionalInfo.add(
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.work, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Employee: ${caller.employeeName}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListTile(
              title: Text(caller.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(numbers.isNotEmpty ? numbers.join(', ') : 'No Number'),
                  ...additionalInfo,
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.call, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => _makePhoneCall(numbers),
                  ),
                  IconButton(
                    icon: Icon(Icons.message, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => _sendMessage(numbers),
                  ),
                ],
              ),
              onTap: () {
                // Optionally, show a bottom sheet or other UI for options.
              },
            );
          },
        );
      }
    } else if (_isLoadingCallLogs) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text('Loading call logs...'),
          ],
        ),
      );
    } else if (_callLogs.isEmpty) {
      return const Center(child: Text('No call logs found'));
    } else {
      return ListView.builder(
        itemCount: _filteredCallLogs.length,
        itemBuilder: (context, index) => CallLogTile(
            callLogEntry: _filteredCallLogs[index],
            localDbService: widget.localDbService,
            firebaseService: widget.firebaseService,
            onRefreshNeeded: () => _fetchCallLogs()
        ),
      );
    }
  }
}