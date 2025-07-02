import '../utils/phone_number_formatter.dart';
import 'package:intl/intl.dart';

class Caller {
  final List<String> phoneNumbers;
  final String name;
  final String searchName;
  final String employeeName;
  final String location;
  final DateTime date;

  const Caller({
    required this.phoneNumbers,
    required this.name,
    required this.searchName,
    required this.employeeName,
    required this.location,
    required this.date
  });

  factory Caller.fromMapRemoteDb(Map<dynamic, dynamic> map) {
    // Safely retrieve and trim the first name.
    String firstName = (map['First Name'] as String?)?.trim() ?? '';

    // Safely retrieve and trim the middle name.
    String? rawMiddleName = map['Middle Name'] as String?;
    rawMiddleName = rawMiddleName?.trim();
    String middleName = (rawMiddleName != null && rawMiddleName != "None") ? rawMiddleName : '';

    // Safely retrieve and trim the last name.
    String? rawLastName = map['Last Name'] as String?;
    rawLastName = rawLastName?.trim();
    String lastName = (rawLastName != null && rawLastName != "None") ? rawLastName : '';

    // Create a full name by joining all non-empty name parts.
    List<String> nameParts = [];
    if (firstName.isNotEmpty) {
      nameParts.add(firstName);
    }
    if (middleName.isNotEmpty) {
      nameParts.add(middleName);
    }
    if (lastName.isNotEmpty) {
      nameParts.add(lastName);
    }
    String fullName = nameParts.isNotEmpty ? nameParts.join(' ') : 'Unknown';

    // Process phone numbers safely by checking null, trimming, and validating against unwanted characters.
    List<String> phoneNumbersMapped = [];

    String? phone1 = map['Phone 1 - Value'] as String?;
    if (phone1 != null && !containsAlphabet(phone1)) {
      phoneNumbersMapped.add(phone1.trim());
    }

    String? phone2 = map['Phone 2 - Value'] as String?;
    if (phone2 != null && !containsAlphabet(phone2)) {
      phoneNumbersMapped.add(phone2.trim());
    }

    String? phone3 = map['Phone 3 - Value'] as String?;
    if (phone3 != null && !containsAlphabet(phone3)) {
      phoneNumbersMapped.add(phone3.trim());
    }

    String location = map['location'] != null?map['location'] as String: '';

    DateFormat format = DateFormat("dd/MM/yyyy");
    DateTime date = map['date'] != null? format.parse(map['date'] as String): DateTime(2000, 1,1);


    return Caller(
        phoneNumbers: phoneNumbersMapped
            .whereType<String>()
            .map((number) => number.trim())
            .where((number) => number.isNotEmpty && number.toLowerCase() != 'na')
            .toList(),
        name: fullName,
        searchName: map['searchName'],
        employeeName: map['employeeName'] as String? ?? '',
        location: location,
        date: date
    );
  }


  factory Caller.fromMapLocalDb(Map<dynamic, dynamic> map) {
    DateFormat format = DateFormat("dd/MM/yyyy");
    return Caller(
        phoneNumbers: map['phoneNumbers'].split(','),
        name: map['name'] as String? ?? 'Unknown',
        searchName: map['searchName'] as String? ?? '',
        employeeName: map['employeeName'] as String? ?? '',
        location: map['location']!=null? map['location'] as String:'',
        date : map['date'] != null?format.parse(map['date'] as String):DateTime(2000, 1,1)

    );
  }

  Map<String, dynamic> toMapRemoteDb() {
    return {
      'Phone 1 - Value': (phoneNumbers != null && phoneNumbers.length > 0) ? phoneNumbers[0] : '',
      'Phone 2 - Value': (phoneNumbers != null && phoneNumbers.length > 1) ? phoneNumbers[1] : '',
      'Phone 3 - Value': (phoneNumbers != null && phoneNumbers.length > 2) ? phoneNumbers[2] : '',
      'First Name': name,
      'searchName': searchName,
      'employeeName': employeeName,
      'location': location,
      'date': date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString()
    };
  }

  Map<String, dynamic> toMapLocalDb() {
    return {
      'name': name,
      'phoneNumbers': phoneNumbers.join(','),
      'searchName': searchName,
      'employeeName': employeeName,
      'location': location,
      'date': date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString()
    };
  }
}