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
            searchName TEXT
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
          'searchName': contact.searchName
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
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
              searchName: ''
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
      // Search contacts by name using the query parameter.
      final contacts = await ContactsService.getContacts(query: query, withThumbnails: false);

      if (contacts.isNotEmpty) {
        for (var contact in contacts) {
          var localCaller = Caller(
              name: contact.displayName ?? query,
              phoneNumbers: contact.phones?.map((item) => item.toString()).toList() ?? [],
              searchName: ''
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
            searchName: ''
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

/*
  Caller _mapToCaller(Map<String, dynamic> map) {
    final phoneNumbersString = map['phoneNumbers'] as String;
    // Split the string by commas and trim each number to remove extra spaces.
    final phoneNumbersList = phoneNumbersString.split(',').map((number) => number.trim()).toList();

    return Caller(
      name: map['name'] as String,
      phoneNumbers: phoneNumbersList,
    );
  }

 */
}