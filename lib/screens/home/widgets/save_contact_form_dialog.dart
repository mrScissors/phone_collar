import 'package:flutter/material.dart';
import 'package:phone_collar/models/caller.dart';
import 'package:phone_collar/services/local_db_service.dart';
import 'package:phone_collar/utils/phone_number_formatter.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/search_name_formatter.dart';

Future<bool> showAddContactForm({
  required BuildContext context,
  required LocalDbService localDbService,
  required FirebaseService firebaseService,
  String? prefillNumber,
}) async {
  final nameController = TextEditingController();
  final phoneNumber1Controller = TextEditingController(
    text: _isValidPhoneNumber(prefillNumber ?? '') ? prefillNumber : '',
  );
  final phoneNumber2Controller = TextEditingController();
  final phoneNumber3Controller = TextEditingController();
  final employeeNameController = TextEditingController();
  final locationController = TextEditingController();
  final dateController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  // Format current date as default
  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  dateController.text = formatDate(selectedDate);

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              appBar: AppBar(
                title: const Text('Add New Contact'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                          top: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                prefixIcon: Icon(Icons.person, color: Colors.black),
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                              ),
                              keyboardType: TextInputType.name,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: phoneNumber1Controller,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number 1 (required)',
                                prefixIcon: Icon(Icons.phone, color: Colors.black),
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: phoneNumber2Controller,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number 2 (optional)',
                                prefixIcon: Icon(Icons.phone, color: Colors.black),
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: phoneNumber3Controller,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number 3 (optional)',
                                prefixIcon: Icon(Icons.phone, color: Colors.black),
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: employeeNameController,
                              decoration: const InputDecoration(
                                labelText: 'Employee Name',
                                prefixIcon: Icon(Icons.badge, color: Colors.black),
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                              ),
                              keyboardType: TextInputType.name,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: locationController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Location',
                                prefixIcon: Icon(Icons.location_on, color: Colors.black),
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                              ),
                              keyboardType: TextInputType.name,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: dateController,
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.black),
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                              ),
                              readOnly: true,
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2101),
                                );
                                if (picked != null && picked != selectedDate) {
                                  setState(() {
                                    selectedDate = picked;
                                    dateController.text = formatDate(picked);
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 24),
                            if (isLoading)
                              const Center(child: CircularProgressIndicator()),
                          ],
                        ),
                      ),
                    ),
                    if (!isLoading)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final phone1 = formatPhoneNumber(phoneNumber1Controller.text.trim());

                                if (name.isEmpty || phone1.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Name and Phone Number 1 are required'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setState(() => isLoading = true);

                                try {
                                  List<String> phoneNumbers = [phone1];
                                  final phone2 = formatPhoneNumber(phoneNumber2Controller.text.trim());
                                  final phone3 = formatPhoneNumber(phoneNumber3Controller.text.trim());
                                  if (phone2.isNotEmpty) phoneNumbers.add(phone2);
                                  if (phone3.isNotEmpty) phoneNumbers.add(phone3);

                                  final searchName = formatSearchName(name);

                                  final caller = Caller(
                                    name: name,
                                    phoneNumbers: phoneNumbers,
                                    searchName: searchName,
                                    employeeName: employeeNameController.text.trim(),
                                    location: locationController.text.trim(),
                                    date: selectedDate, // Use the DateTime object directly
                                  );

                                  await localDbService.saveContact(caller);
                                  await firebaseService.addContact(caller);

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Contact added successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }

                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to add contact: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setState(() => isLoading = false);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  return true;
}

bool _isValidPhoneNumber(String number) {
  if (number.isEmpty) return false;
  final cleanNumber = number.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  return RegExp(r'^\d{1,15}$').hasMatch(cleanNumber);
}