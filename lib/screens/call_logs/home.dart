import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import '../../../services/firebase_service.dart';
import '../../../services/call_log_service.dart';
import '../search_results_screen.dart';
import 'widgets/call_log_tile.dart';

enum SearchType { name, number }

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  _CallLogsScreenState createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  final CallLogService _callLogService = CallLogService();
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  List<CallLogEntry> _callLogs = [];
  List<CallLogEntry> _filteredCallLogs = [];
  bool _isSearching = false;
  SearchType _searchType = SearchType.name;

  @override
  void initState() {
    super.initState();
    _initializeData();
    //_searchController.addListener(_onSearchChanged);
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

  Future<void> _fetchCallLogs() async {
    final logs = await _callLogService.getCallLogs();
    setState(() {
      _callLogs = logs;
      _filteredCallLogs = logs;
    });
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
    // Search in Firebase Realtime Database by name
    final matchingCallers = await _firebaseService.searchByName(query);
    // Navigate to the SearchResultsScreen with the filtered results
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(results: matchingCallers),
      ),
    );
  }

  Future<void> _searchByNumber(String query) async {
    final matchingCallers = await _firebaseService.searchByNumber(query);
    // Navigate to the SearchResultsScreen with the filtered results
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(results: matchingCallers),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
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
      body: _callLogs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _isSearching && _filteredCallLogs.isEmpty
          ? Center(
        child: Text(
            _searchType == SearchType.name
                ? 'No calls found for this name'
                : 'No calls found for this number'
        ),
      )
          : ListView.builder(
        itemCount: _filteredCallLogs.length,
        itemBuilder: (context, index) => CallLogTile(
          callLogEntry: _filteredCallLogs[index],
          firebaseService: _firebaseService,
        ),
      ),
    );
  }
}
