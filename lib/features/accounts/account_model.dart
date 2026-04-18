class Account {
  final String id;
  String name;
  String phone;
  String email;
  double amount;
  DateTime dueDate;
  String status;
  DateTime lastContactDate;

  Account({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.lastContactDate,
  });

  Account copyWith({
    String? name,
    String? phone,
    String? email,
    double? amount,
    DateTime? dueDate,
    String? status,
    DateTime? lastContactDate,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      lastContactDate: lastContactDate ?? this.lastContactDate,
    );
  }

  // JSON serialization for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'lastContactDate': lastContactDate.toIso8601String(),
    };
  }

  static Account fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.tryParse('${json['amount']}') ?? 0.0,
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? '',
      lastContactDate: DateTime.tryParse(json['lastContactDate'] as String? ?? '') ?? DateTime.now(),
    );
  }
}