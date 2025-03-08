import 'package:firebase_database/firebase_database.dart';
import '../models/caller.dart';
import '../utils/phone_number_formatter.dart';
import '../utils/search_name_formatter.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<void> initializeWithCallersData() async {
    final snapshot = await readData('callers');
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
      // Convert the query to lower case (assuming your names are stored in lower case for consistency).
      final queryLower = formatSearchName(query);

      // Perform a range query on the 'name' child.
      // This will fetch all entries where the 'name' field starts with queryLower.
      final snapshot = await _database
          .child('callers')
          .orderByChild('searchName')
          .startAt(queryLower)
          .endAt(queryLower + '\uf8ff')
          .limitToFirst(10) // optional: limit to first 10 matches
          .get();

      if (!snapshot.exists) return [];

      List<Caller> callers = [];
      Map<dynamic, dynamic> callersMap =
      snapshot.value as Map<dynamic, dynamic>;

      callersMap.forEach((key, value) {
        Map<String, dynamic> callerData = Map<String, dynamic>.from(value);
        Caller caller = Caller.fromMap(callerData);
        callers.add(caller);
      });

      return callers;
    } catch (e) {
      print('Error searching callers by name: $e');
      return [];
    }
  }



  Future<List<Caller>> searchByNumber(String number) async {
    try {
      // Request contact permissions
      PermissionStatus permissionStatus = await Permission.contacts.status;
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.contacts.request();
        if (!permissionStatus.isGranted) {
          print('Contact permission denied');
          return [];
        }
      }

      // Format the number for consistency
      final cleanNumber = formatPhoneNumber(number);

      // Search in the phone's contacts first
      Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);
      for (Contact contact in contacts) {
        for (Item phone in contact.phones ?? []) {
          final formattedContactNumber = formatPhoneNumber(phone.value ?? '');
          if (formattedContactNumber.contains(cleanNumber)) {
            // If found in contacts, return it as a Caller object
            return [
              Caller(
                name: contact.displayName ?? 'Unknown',
                phoneNumbers: [formattedContactNumber],
              )
            ];
          }
        }
      }

      // If not found in contacts, search in Firebase
      final DataSnapshot snapshot = await _database
          .child('callers')
          .orderByChild('Phone 1 - Value')
          .startAt(cleanNumber)
          .endAt(cleanNumber + '\uf8ff')
          .limitToFirst(10)
          .get();

      if (snapshot.exists) {
        List<Caller> callers = [];
        Map<dynamic, dynamic> callersMap = snapshot.value as Map<dynamic, dynamic>;

        callersMap.forEach((key, value) {
          Map<String, dynamic> callerData = Map<String, dynamic>.from(value);
          Caller caller = Caller.fromMap(callerData);
          callers.add(caller);
        });
        return callers;
      }
      else{
        final DataSnapshot snapshot = await _database
            .child('callers')
            .orderByChild('Phone 2 - Value')
            .startAt(cleanNumber)
            .endAt(cleanNumber + '\uf8ff')
            .limitToFirst(10)
            .get();

        if (snapshot.exists) {
          List<Caller> callers = [];
          Map<dynamic, dynamic> callersMap = snapshot.value as Map<dynamic, dynamic>;

          callersMap.forEach((key, value) {
            Map<String, dynamic> callerData = Map<String, dynamic>.from(value);
            Caller caller = Caller.fromMap(callerData);
            callers.add(caller);
          });
          return callers;
        }
        else{
          final DataSnapshot snapshot = await _database
              .child('callers')
              .orderByChild('Phone 3 - Value')
              .startAt(cleanNumber)
              .endAt(cleanNumber + '\uf8ff')
              .limitToFirst(10)
              .get();

          if (snapshot.exists) {
            List<Caller> callers = [];
            Map<dynamic, dynamic> callersMap = snapshot.value as Map<dynamic, dynamic>;

            callersMap.forEach((key, value) {
              Map<String, dynamic> callerData = Map<String, dynamic>.from(value);
              Caller caller = Caller.fromMap(callerData);
              callers.add(caller);
            });
            return callers;
          }
        }
      }
      return [];


    } catch (e) {
      print('Error searching by number: $e');
      return [];
    }
  }

  // Method to add a new contact
  Future<void> addContact(String name, String phone) async {
    try {
      final newContactRef = _database.child('callers').push();
      await newContactRef.set({
        'name': name,
        'phone': phone,
        'searchName': formatSearchName(name),
        'timestamp': ServerValue.timestamp,
      });
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
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error updating contact: $e');
      throw e;
    }
  }
}
