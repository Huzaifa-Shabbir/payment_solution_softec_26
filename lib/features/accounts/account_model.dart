class AccountValidationException implements Exception {
  final String message;

  const AccountValidationException(this.message);

  @override
  String toString() => message;
}

class Account {
  final String id;
  String name;
  String phone;
  String email;
  double amount;
  DateTime dueDate;
  String status;
  DateTime lastContactDate;

  static const Set<String> allowedStatuses = {'Pending', 'Paid', 'Overdue'};

  Account({
    required String id,
    required String name,
    required String phone,
    required String email,
    required this.amount,
    required this.dueDate,
    required String status,
    required this.lastContactDate,
  }) : id = id.trim(),
       name = name.trim(),
       phone = phone.trim(),
       email = email.trim(),
       status = status.trim() {
    _validateOrThrow();
  }

  void _validateOrThrow() {
    if (id.isEmpty) {
      throw const AccountValidationException('Account id is required.');
    }
    if (name.isEmpty) {
      throw const AccountValidationException('Name cannot be empty.');
    }

    final phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
    if (phone.isEmpty) {
      throw const AccountValidationException('Phone number is required.');
    }
    if (!phoneRegExp.hasMatch(phone)) {
      throw const AccountValidationException(
        'Phone number must be 7-15 digits and may start with +.',
      );
    }

    final emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (email.isEmpty) {
      throw const AccountValidationException('Email cannot be empty.');
    }
    if (!emailRegExp.hasMatch(email)) {
      throw const AccountValidationException(
        'Please enter a valid email address.',
      );
    }

    if (amount.isNaN || amount.isInfinite) {
      throw const AccountValidationException('Amount must be a valid number.');
    }
    if (amount < 0) {
      throw const AccountValidationException('Amount cannot be negative.');
    }

    if (!allowedStatuses.contains(status)) {
      throw AccountValidationException(
        'Status must be one of: ${allowedStatuses.join(', ')}.',
      );
    }

    if (dueDate.isBefore(lastContactDate)) {
      throw const AccountValidationException(
        'Due date cannot be before last contact date.',
      );
    }
  }

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
    final parsedAmount = (json['amount'] is num)
        ? (json['amount'] as num).toDouble()
        : double.tryParse('${json['amount']}');
    final dueDate = DateTime.tryParse('${json['dueDate'] ?? ''}');
    final lastContactDate = DateTime.tryParse(
      '${json['lastContactDate'] ?? ''}',
    );

    if (parsedAmount == null) {
      throw const AccountValidationException('Amount must be a valid number.');
    }
    if (dueDate == null) {
      throw const AccountValidationException('Due date is invalid.');
    }
    if (lastContactDate == null) {
      throw const AccountValidationException('Last contact date is invalid.');
    }

    return Account(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      email: '${json['email'] ?? ''}',
      amount: parsedAmount,
      dueDate: dueDate,
      status: '${json['status'] ?? ''}',
      lastContactDate: lastContactDate,
    );
  }
}
