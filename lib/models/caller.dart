class Caller {
  final List<String> phoneNumbers;
  final String name;
  final String searchName;

  const Caller({
    required this.phoneNumbers,
    required this.name,
    required this.searchName
  });

  factory Caller.fromMapRemoteDb(Map<dynamic, dynamic> map) {
    return Caller(
      phoneNumbers: [
        map['Phone 1 - Value'],
        map['Phone 2 - Value'],
        map['Phone 3 - Value']
      ]
          .whereType<String>() // Ensure only strings are considered
          .map((number) => number.trim()) // Trim whitespace
          .where((number) => number.isNotEmpty && number.toLowerCase() != 'na') // Remove empty and 'na' values
          .toList(),
      name: map['First Name'] as String? ?? 'Unknown', // Handle missing name gracefully
      searchName: map['searchName']
    );
  }

  factory Caller.fromMapLocalDb(Map<dynamic, dynamic> map) {
    return Caller(
        phoneNumbers: map['phoneNumbers'].split(','),
        name: map['name'] as String? ?? 'Unknown', // Handle missing name gracefully
        searchName: map['searchName']
    );
  }

  Map<String, dynamic> toMapRemoteDb() {
    return {
      'Phone 1 - Value': (phoneNumbers != null && phoneNumbers.length > 0) ? phoneNumbers[0] : '',
      'Phone 2 - Value': (phoneNumbers != null && phoneNumbers.length > 1) ? phoneNumbers[1] : '',
      'Phone 3 - Value': (phoneNumbers != null && phoneNumbers.length > 2) ? phoneNumbers[2] : '',
      'First Name': name,
      'searchName': searchName,
    };
  }

  Map<String, dynamic> toMapLocalDb() {
    return {
      'phoneNumbers': phoneNumbers.join(','),
      'name': name,
      'searchName': searchName,
    };
  }
}