class Caller {
  final List<String> phoneNumbers;
  final String name;

  const Caller({
    required this.phoneNumbers,
    required this.name,
  });

  factory Caller.fromMap(Map<dynamic, dynamic> map) {
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phoneNumbers,
      'name': name,
    };
  }
}