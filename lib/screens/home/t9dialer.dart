import 'package:flutter/material.dart';
import 'package:phone_collar/models/caller.dart';
import 'package:phone_collar/services/local_db_service.dart';
import '../../utils/phone_number_formatter.dart';
import '../../utils/search_name_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

class T9DialerScreen extends StatefulWidget {
  final LocalDbService localDbService;

  const T9DialerScreen({Key? key, required this.localDbService})
      : super(key: key);

  @override
  _T9DialerScreenState createState() => _T9DialerScreenState();
}

class _T9DialerScreenState extends State<T9DialerScreen> {
  final TextEditingController _dialController = TextEditingController();
  List<Caller> _searchResults = [];
  bool _isSearching = false;

  // Map for T9 digit to letters conversion
  final Map<String, String> _t9Map = {
    '2': 'abc',
    '3': 'def',
    '4': 'ghi',
    '5': 'jkl',
    '6': 'mno',
    '7': 'pqrs',
    '8': 'tuv',
    '9': 'wxyz',
  };

  // Generate T9 name pattern from dialed numbers
  String _generateT9NamePattern(String digits) {
    if (digits.isEmpty) return '';

    String pattern = '';
    for (int i = 0; i < digits.length; i++) {
      String digit = digits[i];
      if (_t9Map.containsKey(digit)) {
        pattern += '[${_t9Map[digit]}]';
      } else {
        pattern += digit;
      }
    }
    return pattern;
  }

  Future<void> _onDialChanged() async {
    String query = _dialController.text;
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });

    // Search by both number and T9 name pattern
    List<Caller> numberResults = await widget.localDbService.searchContactsByNumber(query);

    // Generate T9 name pattern and search by name
    String namePattern = _generateT9NamePattern(query);
    List<Caller>? nameResults = await widget.localDbService.searchContactsByT9Name(namePattern);

    // Combine results and remove duplicates
    Set<String> uniqueIds = {};
    List<Caller> combinedResults = [];

    for (var caller in [...numberResults, ...?nameResults]) {
      combinedResults.add(caller);
    }

    setState(() {
      _searchResults = combinedResults;
    });
  }

  void _backspace() {
    final text = _dialController.text;
    if (text.isNotEmpty) {
      setState(() {
        _dialController.text = text.substring(0, text.length - 1);
      });
      _onDialChanged();
    }
  }

  Widget _buildDialPad() {
    List<Map<String, String>> keys = [
      {'number': '1', 'letters': ''},
      {'number': '2', 'letters': 'ABC'},
      {'number': '3', 'letters': 'DEF'},
      {'number': '4', 'letters': 'GHI'},
      {'number': '5', 'letters': 'JKL'},
      {'number': '6', 'letters': 'MNO'},
      {'number': '7', 'letters': 'PQRS'},
      {'number': '8', 'letters': 'TUV'},
      {'number': '9', 'letters': 'WXYZ'},
      {'number': '*', 'letters': ''},
      {'number': '0', 'letters': '+'},
      {'number': '#', 'letters': ''},
    ];

    return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate sizes based on the exact constraints
          final availableHeight = constraints.maxHeight;
          final rowHeight = availableHeight / 5; // 4 rows of buttons + 1 row for call button
          final buttonSize = (constraints.maxWidth / 3) - 8; // 3 buttons per row with small margin

          return Column(
            mainAxisSize: MainAxisSize.min, // Take minimum required space
            children: [
              // First 3 rows (1-9)
              for (int row = 0; row < 3; row++)
                SizedBox(
                  height: rowHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (int col = 0; col < 3; col++)
                        _buildDialButton(keys[row * 3 + col], buttonSize),
                    ],
                  ),
                ),
              // Last row (* 0 #)
              SizedBox(
                height: rowHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Backspace in lower left corner
                    _buildBackspaceButton(buttonSize),
                    // 0 button
                    _buildDialButton(keys[10], buttonSize),
                    // # button
                    _buildDialButton(keys[11], buttonSize),
                  ],
                ),
              ),
              // Call button centered at bottom
              SizedBox(
                height: rowHeight,
                child: Center(
                  child: _buildCallButton(buttonSize),
                ),
              ),
            ],
          );
        }
    );
  }

  Widget _buildDialButton(Map<String, String> keyData, double size) {
    return InkWell(
      onTap: () {
        setState(() {
          _dialController.text += keyData['number']!;
        });
        _onDialChanged();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                keyData['number']!,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (keyData['letters']!.isNotEmpty)
                Text(
                  keyData['letters']!,
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(double size) {
    return InkWell(
      onTap: _backspace,
      onLongPress: () {
        setState(() {
          _dialController.clear();
        });
        _onDialChanged();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: const Center(
          child: Icon(Icons.backspace),
        ),
      ),
    );
  }

  Widget _buildCallButton(double size) {
    return InkWell(
      onTap: () {
        if (_dialController.text.isNotEmpty) {
          _makePhoneCall([_dialController.text]);
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green,
        ),
        child: const Center(
          child: Icon(Icons.call, color: Colors.white, size: 28),
        ),
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

  void _sendMessage(String number) async {
    // Your SMS logic here
  }

  void _showAddContactForm(String text, {String? prefillNumber}) {
    final nameController = TextEditingController();
    final phoneNumber1Controller = TextEditingController(
        text: prefillNumber != null && !containsAlphabet(prefillNumber)
            ? prefillNumber
            : '');
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
                          content: Text(
                              'Name and Phone Number 1 are required'),
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
                          content: Text(
                              'Failed to add contact: ${e.toString()}'),
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
  void dispose() {
    _dialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set dial pad container height to 35% of screen height.
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialer'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search query (dialed number) at the top.
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _dialController,
                decoration: const InputDecoration(
                  hintText: 'Dial number',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            ),
            // Expanded area for search results.
            Expanded(
              child: _isSearching
                  ? (_searchResults.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No contact found for "${_dialController.text}"'),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _makePhoneCall([_dialController.text]),
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _sendMessage(_dialController.text),
                          icon: const Icon(Icons.message),
                          label: const Text('Message'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _showAddContactForm(_dialController.text),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Contact'),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final caller = _searchResults[index];
                  final List<String> numbers = caller.phoneNumbers
                      .where((number) => number.trim().isNotEmpty)
                      .toList();
                  return ListTile(
                    title: Text(caller.name),
                    subtitle: Text(numbers.join(', ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _makePhoneCall([numbers.first]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.blue),
                          onPressed: () => _sendMessage(numbers.first),
                        ),
                      ],
                    ),
                  );
                },
              ))
                  : Container(),
            ),
            const Divider(),
            // Dial pad at the bottom in a container of fixed height.
            Container(
              height: screenHeight * 0.35,
              child: _buildDialPad(),
            ),
            // Extra bottom padding.
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}