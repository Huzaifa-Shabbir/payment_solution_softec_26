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
}