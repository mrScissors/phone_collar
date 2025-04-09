import 'package:firebase_database/firebase_database.dart';
import '../models/caller.dart';
import '../utils/phone_number_formatter.dart';
import '../utils/search_name_formatter.dart';
// Remove: import 'package:contacts_service/contacts_service.dart';
// Remove: import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref('callers');
  List<Caller> _callersCache = [];

  Future<bool> initializeWithCallersData() async {
    try {
      final snapshot = await readData('callers');
      return true;
      // Continue processing the snapshot if necessary.
    } catch (e) {
      // Check if the error message indicates a permission issue.
      if (e.toString().contains("PERMISSION_DENIED") ||
          e.toString().toLowerCase().contains("permission")) {
        return false;
      } else {
        // Handle other errors accordingly.
        throw Exception('Error initializing callers data: $e');
        return false;
      }
    }
  }

  Future<void> createData(String path, Map<String, dynamic> data) async {
    await _database.child(path).set(data);
  }

  Future<DataSnapshot> readData(String path) async {
    return await _database.child(path).get();
  }

  Future<void> updateData(String path, Map<String, dynamic> data) async {
    await _database.child(path).update(data);
  }

  Future<void> deleteData(String path) async {
    await _database.child(path).remove();
  }

  Future<List<Caller>> searchByName(String query) async {
    try {
      final queryLower = formatSearchName(query);

      final snapshot = await _database
          .child('callers')
          .orderByChild('searchName')
          .startAt(queryLower)
          .endAt(queryLower + '\uf8ff')
          .limitToFirst(10)
          .get();

      if (!snapshot.exists) return [];

      List<Caller> callers = [];
      Map<dynamic, dynamic> callersMap =
      snapshot.value as Map<dynamic, dynamic>;

      callersMap.forEach((key, value) {
        Map<String, dynamic> callerData = Map<String, dynamic>.from(value);
        Caller caller = Caller.fromMapRemoteDb(callerData);
        callers.add(caller);
      });

      return callers;
    } catch (e) {
      print('Error searching callers by name: $e');
      return [];
    }
  }

  /// -------------------------------------------------
  /// REVISED searchByNumber METHOD USING flutter_contacts
  /// -------------------------------------------------
  Future<List<Caller>> searchByNumber(String number) async {
    try {
      // 1) Request contact permissions via flutter_contacts
      final permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        print('Contact permission denied');
        return [];
      }

      // 2) Format the incoming number for consistency
      final cleanNumber = formatPhoneNumber(number);

      // 3) Fetch all contacts from the device with phone properties
      final contacts = await FlutterContacts.getContacts(withProperties: true);

      // 4) Loop through each contact and check if any phone matches user’s query
      for (Contact contact in contacts) {
        for (var phone in contact.phones) {
          final formattedContactNumber = formatPhoneNumber(phone.number);
          if (formattedContactNumber.contains(cleanNumber)) {
            // If a match is found in local device contacts, return it
            return [
              Caller(
                name: contact.displayName.isNotEmpty
                    ? contact.displayName
                    : 'Unknown',
                phoneNumbers: [formattedContactNumber],
                searchName: '',
                employeeName: 'PhoneContact',
              )
            ];
          }
        }
      }

      // ------------------------------------------------
      // If not found in local device, now search Firebase
      // ------------------------------------------------

      // 5) Search for 'Phone 1 - Value'
      final snapshot1 = await _database
          .child('callers')
          .orderByChild('Phone 1 - Value')
          .startAt(cleanNumber)
          .endAt(cleanNumber + '\uf8ff')
          .limitToFirst(10)
          .get();

      if (snapshot1.exists) {
        return _parseCallersFromSnapshot(snapshot1);
      }

      // 6) Search for 'Phone 2 - Value'
      final snapshot2 = await _database
          .child('callers')
          .orderByChild('Phone 2 - Value')
          .startAt(cleanNumber)
          .endAt(cleanNumber + '\uf8ff')
          .limitToFirst(10)
          .get();

      if (snapshot2.exists) {
        return _parseCallersFromSnapshot(snapshot2);
      }

      // 7) Search for 'Phone 3 - Value'
      final snapshot3 = await _database
          .child('callers')
          .orderByChild('Phone 3 - Value')
          .startAt(cleanNumber)
          .endAt(cleanNumber + '\uf8ff')
          .limitToFirst(10)
          .get();

      if (snapshot3.exists) {
        return _parseCallersFromSnapshot(snapshot3);
      }

      // If no match in local device or Firebase
      return [];
    } catch (e) {
      print('Error searching by number: $e');
      return [];
    }
  }

  // Helper method to parse snapshot into Caller objects
  List<Caller> _parseCallersFromSnapshot(DataSnapshot snapshot) {
    List<Caller> callers = [];
    Map<dynamic, dynamic> callersMap = snapshot.value as Map<dynamic, dynamic>;

    callersMap.forEach((key, value) {
      Map<String, dynamic> callerData = Map<String, dynamic>.from(value);
      Caller caller = Caller.fromMapRemoteDb(callerData);
      callers.add(caller);
    });

    return callers;
  }

  // Method to add a new contact
  Future<void> addContact(Caller contact) async {
    try {
      final newContactRef = _database.push();
      final data = contact.toMapRemoteDb();
      await newContactRef.set(data);
    } catch (e) {
      print('Error adding contact: $e');
      throw e;
    }
  }

  // Method to update a contact
  Future<void> updateContact(String id, String name, String phone) async {
    try {
      await _database.child('callers').child(id).update({
        'name': name,
        'phone': phone,
        'searchName': formatSearchName(name),
      });
    } catch (e) {
      print('Error updating contact: $e');
      throw e;
    }
  }

  Future<(bool, List<Caller>)> getAllContacts() async {
    bool isPermissionGranted = await initializeWithCallersData();
    if (!isPermissionGranted) {
      return (false, List<Caller>.from(_callersCache));
    }
    final snapshot = await _database.get();
    if (snapshot.exists) {
      _callersCache = _parseCallers(snapshot);
    }
    return (true, List<Caller>.from(_callersCache));
  }


  List<Caller> _parseCallers(DataSnapshot snapshot) {
    final callers = <Caller>[];

    if (snapshot.value is List) {
      // If Firebase returns a List
      final dataList = snapshot.value as List<Object?>;
      for (var element in dataList) {
        if (element is Map<dynamic, dynamic>) {
          try {
            final caller = Caller.fromMapRemoteDb(element);
            callers.add(caller);
          } catch (e) {
            print('Error parsing caller data: $e');
          }
        }
      }
    } else if (snapshot.value is Map) {
      // If Firebase returns a Map
      final dataMap = snapshot.value as Map<dynamic, dynamic>;
      dataMap.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          try {
            final caller = Caller.fromMapRemoteDb(value);
            callers.add(caller);
          } catch (e) {
            print('Error parsing caller data: $e');
          }
        }
      });
    }

    return callers;
  }
}
