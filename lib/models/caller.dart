import '../utils/phone_number_formatter.dart';

class Caller {
  final List<String> phoneNumbers;
  final String name;
  final String searchName;
  final String employeeName;

  const Caller({
    required this.phoneNumbers,
    required this.name,
    required this.searchName,
    required this.employeeName
  });

  factory Caller.fromMapRemoteDb(Map<dynamic, dynamic> map) {
    String firstName = (map['First Name'] as String?)?.trim() ?? '';
    String middleName = map['Middle Name'] != "None"?map['Middle Name'].trim() : '';
    String lastName = map['Last Name'] != "None"?map['Last Name'].trim() : '';

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


    List<String> phoneNumbersMapped = [];

    if (map['Phone 1 - Value'] != null && !containsAlphabet(map['Phone 1 - Value'])) {
      phoneNumbersMapped.add(map['Phone 1 - Value'].toString());
    }
    if (map['Phone 2 - Value'] != null && !containsAlphabet(map['Phone 2 - Value'])) {
      //phoneNumbersMapped += phoneNumbersMapped.isNotEmpty ? ', ' : '';
      phoneNumbersMapped.add(map['Phone 2 - Value'].toString());
    }
    if (map['Phone 3 - Value'] != null && !containsAlphabet(map['Phone 3 - Value'])) {
      //phoneNumbersMapped += phoneNumbersMapped.isNotEmpty ? ', ' : '';
      phoneNumbersMapped.add(map['Phone 3 - Value'].toString());
    }

    return Caller(
        phoneNumbers: phoneNumbersMapped
            .whereType<String>()
            .map((number) => number.trim())
            .where((number) => number.isNotEmpty && number.toLowerCase() != 'na')
            .toList(),
        name: fullName,
        searchName: map['searchName'],
        employeeName: map['employeeName'] as String? ?? '',
    );
  }


  factory Caller.fromMapLocalDb(Map<dynamic, dynamic> map) {
    return Caller(
        phoneNumbers: map['phoneNumbers'].split(','),
        name: map['name'] as String? ?? 'Unknown',
        searchName: map['searchName'] as String? ?? '',
        employeeName: map['employeeName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMapRemoteDb() {
    return {
      'Phone 1 - Value': (phoneNumbers != null && phoneNumbers.length > 0) ? phoneNumbers[0] : '',
      'Phone 2 - Value': (phoneNumbers != null && phoneNumbers.length > 1) ? phoneNumbers[1] : '',
      'Phone 3 - Value': (phoneNumbers != null && phoneNumbers.length > 2) ? phoneNumbers[2] : '',
      'First Name': name,
      'searchName': searchName,
      'employeeName': employeeName
    };
  }

  Map<String, dynamic> toMapLocalDb() {
    return {
      'phoneNumbers': phoneNumbers.join(','),
      'name': name,
      'searchName': searchName,
      'employeeName': employeeName
    };
  }
}