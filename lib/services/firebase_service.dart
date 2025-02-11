import 'package:firebase_database/firebase_database.dart';
import '../models/caller.dart';
import '../utils/phone_number_formatter.dart';

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Future<void> initializeWithSampleData() async {
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

  Future<String> getCallerName(String? phoneNumber) async {
    if (phoneNumber == null) return 'Unknown';

    final formattedNumber = formatPhoneNumber(phoneNumber);

    try {
      final snapshot = await readData('callers/$formattedNumber');

      if (snapshot.exists) {
        final caller = Caller.fromMap(snapshot.value as Map<dynamic, dynamic>);
        return caller.name;
      }

      return formattedNumber;
    } catch (e) {
      print('Error fetching caller name: $e');
      return formattedNumber;
    }
  }
}