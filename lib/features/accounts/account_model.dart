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
  // keep status for backwards compatibility but NOT required by Add screen
  String status;
  DateTime lastContactDate;
  // New flag to represent paid/done state
  bool isPaid;

  // removed strict allowedStatuses enforcement - status may be legacy/backfilled
  // static const Set<String> allowedStatuses = {'Pending', 'Paid', 'Overdue'};

  // Updated constructor: use plain parameter types and assign fields in initializer list
  Account({
    required String id,
    required String name,
    required String phone,
    required String email,
    required double amount,
    required DateTime dueDate,
    String status = '',
    required DateTime lastContactDate,
    bool isPaid = false,
  })  : id = id.trim(),
        name = name.trim(),
        phone = phone.trim(),
        email = email.trim(),
        amount = amount,
        dueDate = dueDate,
        status = status.trim(),
        lastContactDate = lastContactDate,
        isPaid = isPaid {
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

    // Due date should be >= last contact date (logical check)
    if (dueDate.isBefore(lastContactDate)) {
      throw const AccountValidationException(
        'Due date cannot be before last contact date.',
      );
    }
  }

  // Computed status based on isPaid and dates (used by UI)
  String get computedStatus {
    if (isPaid) return 'Done';
    final now = DateTime.now();
    if (dueDate.isBefore(now)) return 'Overdue';
    return 'Pending';
  }

  Account copyWith({
    String? name,
    String? phone,
    String? email,
    double? amount,
    DateTime? dueDate,
    String? status,
    DateTime? lastContactDate,
    bool? isPaid,
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
      isPaid: isPaid ?? this.isPaid,
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
      'isPaid': isPaid,
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

    // Support legacy status values mapping to isPaid
    final rawStatus = '${json['status'] ?? ''}';
    bool legacyPaid = false;
    final low = rawStatus.toLowerCase();
    if (low == 'paid' || low == 'done') legacyPaid = true;

    return Account(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      email: '${json['email'] ?? ''}',
      amount: parsedAmount,
      dueDate: dueDate,
      status: rawStatus,
      lastContactDate: lastContactDate,
      isPaid: (json['isPaid'] == true) || legacyPaid,
    );
  }
}
