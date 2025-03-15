import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:phone_collar/utils/phone_number_formatter.dart';
import 'package:phone_collar/utils/search_name_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/firebase_service.dart';
import '../../../services/call_log_service.dart';
import '../../models/caller.dart';
import '../../services/notification_service.dart';
import 'widgets/call_log_tile.dart';
import '../../call_event_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//import 'package:permission_handler/permission_handler.dart';
import '../../../services/local_db_service.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum SearchType { name, number }

class CallLogsScreen extends StatefulWidget {
  final LocalDbService localDbService;

  const CallLogsScreen({Key? key, required this.localDbService}) : super(key: key);

  @override
  _CallLogsScreenState createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  final CallLogService _callLogService = CallLogService();
  final FirebaseService _firebaseService = FirebaseService();
  // Removed internal instantiation of LocalDbService; now use widget.localDbService
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
    _initializeNotifications();
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

    if (lastSyncTime == null ||
        (currentTime - lastSyncTime) > thresholdForResyncInMilliSeconds) {
      await syncContacts();
      await prefs.setInt('lastSyncTime', currentTime);
    }
  }

  Future<void> _initializeLocalDb() async {
    await widget.localDbService.initialize();
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
      widget.localDbService.clearLocalDb();

      Iterable<Contact> contactsLocal =
      await ContactsService.getContacts(withThumbnails: false);
      List<Caller> callersLocal = [];

      for (Contact contact in contactsLocal) {
        var searchName = formatSearchName(contact.displayName ?? '');
        var callerLocal = Caller(
          name: contact.displayName ?? 'Unknown',
          phoneNumbers: contact.phones?.map((item) => item.value ?? '').toList() ?? [],
          searchName: searchName,
        );
        callersLocal.add(callerLocal);
      }
      await widget.localDbService.saveContacts(callersLocal);

      final contacts = await _firebaseService.getAllContacts();

      await widget.localDbService.saveContacts(contacts);


      // Close the loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Successfully synced ${contacts.length} contacts'),
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
        final localContact =
        await widget.localDbService.getContactByNumber(number);

        if (localContact != null) {
          NotificationService.showIncomingCallNotification(localContact.name);
          return;
        }
      } catch (e) {
        print('Error in call event listener: $e');
        if (mounted) {
          NotificationService.showIncomingCallNotification(number ?? 'Unknown');
        }
      }
    });
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

  void _showAddContactForm({String? prefillNumber}) {
    final nameController = TextEditingController();
    final phoneNumber1Controller = TextEditingController(
        text: !containsAlphabet(prefillNumber ?? '') ? prefillNumber : '');
    final phoneNumber2Controller = TextEditingController();
    final phoneNumber3Controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Contact'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneNumber1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number 1 (required)',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneNumber2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number 2 (optional)',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneNumber3Controller,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number 3 (optional)',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 20.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    final name = nameController.text.trim();
                    final phone1 = phoneNumber1Controller.text.trim();

                    if (name.isEmpty || phone1.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Name and Phone Number 1 are required'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      List<String> phoneNumbers = [];
                      if (phone1.isNotEmpty) phoneNumbers.add(phone1);

                      final phone2 = phoneNumber2Controller.text.trim();
                      if (phone2.isNotEmpty) phoneNumbers.add(phone2);

                      final phone3 = phoneNumber3Controller.text.trim();
                      if (phone3.isNotEmpty) phoneNumbers.add(phone3);

                      final searchName = formatSearchName(name);

                      final caller = Caller(
                        name: name,
                        phoneNumbers: phoneNumbers,
                        searchName: searchName,
                      );

                      await widget.localDbService.saveContact(caller);
                      await _firebaseService.addContact(caller);

                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contact added successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      print('Error adding contact: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to add contact: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
        actions: [
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
            icon: const Icon(Icons.sync, color: Colors.black),
            label: const Text(
              'Sync Contacts',
              style: TextStyle(color: Colors.black),
            ),
            onPressed: syncContacts,
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
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
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
        onPressed: _showAddContactForm,
        tooltip: 'Add Contact',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _makePhoneCall(List<String> numbers) async {
    if (numbers.isEmpty) return;
    if (numbers.length == 1) {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: numbers.first,
      );
      await launchUrl(launchUri);
    } else {
      final selectedNumber = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Number to Call'),
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
        final Uri launchUri = Uri(
          scheme: 'tel',
          path: selectedNumber,
        );
        await launchUrl(launchUri);
      }
    }
  }

  void _sendMessage(List<String> numbers) async {
    if (numbers.isEmpty) return;
    if (numbers.length == 1) {
      final Uri launchUri = Uri(
        scheme: 'sms',
        path: numbers.first,
      );
      await launchUrl(launchUri);
    } else {
      final selectedNumber = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Number to Message'),
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
        final Uri launchUri = Uri(
          scheme: 'sms',
          path: selectedNumber,
        );
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
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: const Text('Call'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _sendMessage([_searchController.text]),
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text('Message'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () =>
                    _showAddContactForm(prefillNumber: _searchController.text),
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text('Add Contact'),
              ),
            ],
          ),
        );
      } else {
        return ListView.builder(
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final caller = _searchResults[index];
            final List<String> numbers = caller.phoneNumbers
                .where((number) => number.trim().isNotEmpty)
                .toList();
            return ListTile(
              title: Text(caller.name),
              subtitle: Text(numbers.isNotEmpty ? numbers.join(', ') : 'No Number'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () => _makePhoneCall(numbers),
                  ),
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.blue),
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
    } else if (_callLogs.isEmpty) {
      return const Center(child: Text('No call logs found'));
    } else {
      return ListView.builder(
        itemCount: _filteredCallLogs.length,
        itemBuilder: (context, index) => CallLogTile(
          callLogEntry: _filteredCallLogs[index],
          localDbService: widget.localDbService,
        ),
      );
    }
  }
}
