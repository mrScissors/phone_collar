import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/caller.dart';
import '../utils/phone_number_formatter.dart';
import '../utils/search_name_formatter.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';


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

  void clearLocalDb(){
    final batch = _database!.batch();
    batch.delete(_tableName);
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


  Future<Caller?> getContactByNumber(String? number) async {
    try {
      // Early return if number is null
      if (number == null) return null;
      final formattedNumber = formatPhoneNumber(number);



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

      // Request contact permissions
      PermissionStatus permissionStatus = await Permission.contacts.status;
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.contacts.request();
        if (!permissionStatus.isGranted) {
          print('Contact permission denied');
          return null;
        }
      }

      try {
        final contacts = await ContactsService.getContactsForPhone(formattedNumber, withThumbnails: false);
        if (contacts.isNotEmpty) {
          final contact = contacts.first;
          return Caller(
              name: contact.displayName ?? number,
              phoneNumbers: [formattedNumber],
              searchName: '',
              employeeName: 'PhoneContact'
          );
        }
      } catch (e) {
        print('Error with direct phone lookup: $e');
      }

      return null;
    } catch (e) {
      print('Error searching by number: $e');
      return null;
    }


  }


  Future<List<Caller>> searchContactsByName(String query) async {
    if (_database == null) return [];
    var formattedName = formatSearchName(query);
    final results = await _database!.query(
      _tableName,
      where: 'searchName LIKE ?',
      whereArgs: ['%$formattedName%'],
    );
    if (results.isNotEmpty){
      return results.map(Caller.fromMapLocalDb).toList();
    }

    List<Caller> localSearchResult = [];

    try {
      final contacts = await ContactsService.getContacts(query: query, withThumbnails: false);

      if (contacts.isNotEmpty) {
        for (var contact in contacts) {
          var localCaller = Caller(
              name: contact.displayName ?? query,
              phoneNumbers: contact.phones?.map((item) => item.toString()).toList() ?? [],
              searchName: '',
              employeeName: 'PhoneContact'
          );
          localSearchResult.add(localCaller);
        }
      }

      return localSearchResult;
    } catch (e) {
      print('Error with direct name lookup: $e');
      return localSearchResult;
    }
  }

  Future<List<Caller>> searchContactsByNumber(String query) async {
    if (_database == null) return [];

    final formattedQuery = formatPhoneNumber(query);
    final results = await _database!.query(
      _tableName,
      where: 'phoneNumbers LIKE ?',
      whereArgs: ['%$formattedQuery%'],
    );
    if (results.isNotEmpty) {
      return results.map(Caller.fromMapLocalDb).toList();
    }

    List<Caller> localSearchResult = [];
    // Request contact permissions
    PermissionStatus permissionStatus = await Permission.contacts.status;
    if (!permissionStatus.isGranted) {
      permissionStatus = await Permission.contacts.request();
      if (!permissionStatus.isGranted) {
        print('Contact permission denied');
        return localSearchResult;
      }
    }

    try {
      final contacts = await ContactsService.getContactsForPhone(formattedQuery, withThumbnails: false);
      if (contacts.isNotEmpty) {
        final contact = contacts.first;
        var localCaller =  Caller(
            name: contact.displayName ?? formattedQuery,
            phoneNumbers: contact.phones!.map((item) => item.toString()).toList(),
            searchName: '',
            employeeName: 'PhoneContact'
        );
        localSearchResult.add(localCaller);
      }
      return localSearchResult;
    } catch (e) {
      print('Error with direct phone lookup: $e');
    }
    return localSearchResult;
  }

  Future<List<Caller>> getAllContacts() async {
    if (_database == null) await initialize();

    final results = await _database!.query(_tableName);
    return results.map(Caller.fromMapLocalDb).toList();
  }

  Future<void> saveContact(Caller caller) async {
    try {
      // Ensure database is initialized
      if (_database == null) {
        await initialize();
      }
      var phoneNumbersForLocalDb = caller.phoneNumbers.join(',');
      await _database!.insert('contacts', {
        'name': caller.name,
        'searchName': caller.searchName,
        'phoneNumbers': phoneNumbersForLocalDb,
        'employeeName': caller.employeeName
      });
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
          // Add each character as an alternative with %
          sqlPattern += '(';
          for (int j = 0; j < chars.length; j++) {
            sqlPattern += chars[j];
            if (j < chars.length - 1) {
              sqlPattern += '|';
            }
          }
          sqlPattern += ')';
          // Skip to after closing bracket
          i = closingBracket;
        }
      } else {
        // Add non-bracket characters directly
        sqlPattern += t9Pattern[i];
      }
    }

    // Using a raw query for regex matching
    // Note: SQLite regex support may be limited - you might need to use multiple LIKE clauses instead
    final List<Map<String, Object?>>? maps = await _database?.rawQuery('''
    SELECT * FROM $_tableName 
    WHERE searchName REGEXP ?
  ''', ['^$sqlPattern.*']);

    return maps?.map((map) {
      return Caller.fromMapLocalDb(map);
    }).toList();
  }
}