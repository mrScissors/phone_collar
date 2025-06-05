import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/caller.dart';
import '../utils/phone_number_formatter.dart';
import '../utils/search_name_formatter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class LocalDbService {
  static Database? _database;
  static const String _tableName = 'contacts';

  Future<void> initialize() async {
    if (_database != null) return;

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'contacts_database.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          '''
          CREATE TABLE $_tableName(
            name TEXT,
            phoneNumbers TEXT,
            searchName TEXT,
            employeeName TEXT
          )
          ''',
        );
      },
    );
  }

  Future<void> clearLocalDb() async {
    // Drop the table if it exists
    await _database?.execute("DROP TABLE IF EXISTS $_tableName");

    // Recreate the table with the desired schema
    await _database?.execute('''
    CREATE TABLE $_tableName(
      name TEXT,
      phoneNumbers TEXT,
      searchName TEXT,
      employeeName TEXT
    )
  ''');
  }

  Future<void> saveContacts(List<Caller> contacts) async {
    if (_database == null) await initialize();

    final batch = _database!.batch();
    for (final contact in contacts) {
      batch.insert(
        _tableName,
        {
          'name': contact.name,
          'phoneNumbers': contact.phoneNumbers.join(', '),
          'searchName': contact.searchName,
          'employeeName': contact.employeeName
        },
        conflictAlgorithm: ConflictAlgorithm.ignore, // Prevent overwriting
      );
    }

    await batch.commit(noResult: true);
  }

  /// ------------------------------------------
  /// GET CONTACT BY NUMBER (using flutter_contacts)
  /// ------------------------------------------
  Future<Caller?> getContactByNumber(String? number) async {
    try {
      if (number == null) return null;
      final formattedNumber = formatPhoneNumber(number);

      // 1) First, check our local DB
      if (_database != null) {
        final results = await _database!.query(
          _tableName,
          where: 'phoneNumbers LIKE ?',
          whereArgs: ['%$formattedNumber%'],
          limit: 1,
        );
        if (results.isNotEmpty) {
          return Caller.fromMapLocalDb(results.first);
        }
      }
/*
      // 2) If not found, attempt to get from device contacts
      //    using flutter_contacts, by searching all phone numbers
      final permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        print('User denied contact permission');
        return null;
      }

      // We fetch all device contacts with phone numbers
      final deviceContacts = await FlutterContacts.getContacts(withProperties: true);

      for (final c in deviceContacts) {
        for (final phone in c.phones) {
          final devPhone = formatPhoneNumber(phone.number);
          if (devPhone.contains(formattedNumber)) {
            // Return the first matching contact
            return Caller(
              name: c.displayName.isNotEmpty ? c.displayName : number,
              phoneNumbers: [devPhone],
              searchName: '',
              employeeName: 'PhoneContact',
            );
          }
        }
      }
*/
      // Not found in local DB or in device contacts
      return null;
    } catch (e) {
      print('Error searching by number: $e');
      return null;
    }
  }

  /// ------------------------------------------
  /// SEARCH CONTACTS BY NAME (flutter_contacts)
  /// ------------------------------------------
  Future<List<Caller>> searchContactsByName(String query) async {
    if (_database == null) return [];

    // 1) Check local DB
    final formattedName = formatSearchName(query);
    final results = await _database!.query(
      _tableName,
      where: 'searchName LIKE ?',
      whereArgs: ['%$formattedName%'],
    );
    if (results.isNotEmpty) {
      return results.map(Caller.fromMapLocalDb).toList();
    }

    // 2) If not found, search device contacts with flutter_contacts
    final localSearchResult = <Caller>[];
  /*
    try {
      final permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        print('User denied contact permission');
        return [];
      }


      // flutter_contacts: we can do name-based searching by passing `query`
      final deviceContacts = await FlutterContacts.getContacts(withProperties: true);

      // Manually filter by name
      final filtered = deviceContacts.where((c) {
        // Adjust for case-insensitive comparison
        return c.displayName.toLowerCase().contains(query.toLowerCase());
      }).toList();


      for (final c in filtered) {
        final phoneNumbers = c.phones.map((p) => p.number).toList();
        final localCaller = Caller(
          name: c.displayName.isNotEmpty ? c.displayName : query,
          phoneNumbers: phoneNumbers,
          searchName: '',        // If you like, you can pre-format it
          employeeName: 'PhoneContact',
        );
        localSearchResult.add(localCaller);
      }
      return localSearchResult;
    } catch (e) {
      print('Error with name lookup using flutter_contacts: $e');
      return [];
    }
    */

  return localSearchResult;
  }

  /// ------------------------------------------
  /// SEARCH CONTACTS BY NUMBER (flutter_contacts)
  /// ------------------------------------------
  Future<List<Caller>> searchContactsByNumber(String query) async {
    if (_database == null) return [];
    if (containsAlphabet(query)) return [];
    // 1) First, check local DB
    final formattedQuery = formatPhoneNumber(query);
    final results = await _database!.query(
      _tableName,
      where: 'phoneNumbers LIKE ?',
      whereArgs: ['%$formattedQuery%'],
    );
    if (results.isNotEmpty) {
      return results.map(Caller.fromMapLocalDb).toList();
    }

    // 2) If not found in local DB, fetch from device contacts
    final localSearchResult = <Caller>[];
    /*
    try {
      final permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        print('User denied contact permission');
        return [];
      }

      // FlutterContacts does not have a direct "getContactsForPhone",
      // so we fetch all and manually filter
      final deviceContacts = await FlutterContacts.getContacts(withProperties: true);

      for (final c in deviceContacts) {
        for (final phone in c.phones) {
          final devPhone = formatPhoneNumber(phone.number);
          if (devPhone.contains(formattedQuery)) {
            // Found a match, add to results
            final localCaller = Caller(
              name: c.displayName.isNotEmpty ? c.displayName : formattedQuery,
              phoneNumbers: c.phones.map((p) => formatPhoneNumber(p.number)).toList(),
              searchName: '',
              employeeName: 'PhoneContact',
            );
            localSearchResult.add(localCaller);
            break; // Optionally break if you only want first match per contact
          }
        }
      }
      return localSearchResult;
    } catch (e) {
      print('Error with direct phone lookup using flutter_contacts: $e');
      return [];
    }
*/
    return localSearchResult;
  }

  Future<List<Caller>> getAllContacts() async {
    if (_database == null) await initialize();
    final results = await _database!.query(_tableName);
    return results.map(Caller.fromMapLocalDb).toList();
  }

  Future<void> saveContact(Caller caller) async {
    try {
      if (_database == null) await initialize();
      final phoneNumbersForLocalDb = caller.phoneNumbers.join(',');
      await _database!.insert(
        _tableName,
        {
          'name': caller.name,
          'searchName': caller.searchName,
          'phoneNumbers': phoneNumbersForLocalDb,
          'employeeName': caller.employeeName
        },
      );
      print('Contact saved to local DB: ${caller.name}');
    } catch (e) {
      print('Error saving contact to local DB: $e');
      throw Exception('Failed to save contact to local database: $e');
    }
  }

  Future<List<Caller>?> searchContactsByT9Name(String t9Pattern) async {
    if (t9Pattern.isEmpty) {
      return [];
    }

    String sqlPattern = '';
    for (int i = 0; i < t9Pattern.length; i++) {
      if (t9Pattern[i] == '[') {
        // Find the closing bracket
        int closingBracket = t9Pattern.indexOf(']', i);
        if (closingBracket != -1) {
          // Extract characters between brackets
          String chars = t9Pattern.substring(i + 1, closingBracket);
          // Add each character as an alternative with |
          sqlPattern += '(';
          for (int j = 0; j < chars.length; j++) {
            sqlPattern += chars[j];
            if (j < chars.length - 1) {
              sqlPattern += '|';
            }
          }
          sqlPattern += ')';
          i = closingBracket;
        }
      } else {
        sqlPattern += t9Pattern[i];
      }
    }

    final List<Map<String, Object?>>? maps = await _database?.rawQuery('''
      SELECT * FROM $_tableName
      WHERE searchName REGEXP ?
    ''', ['^$sqlPattern.*']);

    return maps?.map((map) => Caller.fromMapLocalDb(map)).toList();
  }
}
