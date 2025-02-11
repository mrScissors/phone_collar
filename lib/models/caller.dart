class Caller {
  final String phone;
  final String name;

  const Caller({
    required this.phone,
    required this.name,
  });

  factory Caller.fromMap(Map<dynamic, dynamic> map) {
    return Caller(
      phone: map['phone'] as String,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'name': name,
    };
  }
}