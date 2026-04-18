import 'package:flutter_test/flutter_test.dart';
import 'package:payment_solution_softec_26/features/accounts/account_model.dart';

void main() {
  Account buildValidAccount() {
    return Account(
      id: '1',
      name: 'John Doe',
      phone: '+1234567890',
      email: 'john@example.com',
      amount: 120.50,
      dueDate: DateTime(2026, 5, 10),
      status: 'Pending',
      lastContactDate: DateTime(2026, 5, 1),
    );
  }

  test('creates a valid account', () {
    final account = buildValidAccount();

    expect(account.name, 'John Doe');
    expect(account.amount, 120.50);
  });

  test('throws when name is empty', () {
    expect(
      () => Account(
        id: '1',
        name: '   ',
        phone: '+1234567890',
        email: 'john@example.com',
        amount: 100,
        dueDate: DateTime(2026, 5, 10),
        status: 'Pending',
        lastContactDate: DateTime(2026, 5, 1),
      ),
      throwsA(isA<AccountValidationException>()),
    );
  });

  test('throws when amount is negative', () {
    expect(
      () => Account(
        id: '1',
        name: 'John Doe',
        phone: '+1234567890',
        email: 'john@example.com',
        amount: -1,
        dueDate: DateTime(2026, 5, 10),
        status: 'Pending',
        lastContactDate: DateTime(2026, 5, 1),
      ),
      throwsA(isA<AccountValidationException>()),
    );
  });

  test('throws when due date is before last contact date', () {
    expect(
      () => Account(
        id: '1',
        name: 'John Doe',
        phone: '+1234567890',
        email: 'john@example.com',
        amount: 100,
        dueDate: DateTime(2026, 5, 1),
        status: 'Pending',
        lastContactDate: DateTime(2026, 5, 10),
      ),
      throwsA(isA<AccountValidationException>()),
    );
  });

  test('throws when status is invalid', () {
    expect(
      () => Account(
        id: '1',
        name: 'John Doe',
        phone: '+1234567890',
        email: 'john@example.com',
        amount: 100,
        dueDate: DateTime(2026, 5, 10),
        status: 'Unknown',
        lastContactDate: DateTime(2026, 5, 1),
      ),
      throwsA(isA<AccountValidationException>()),
    );
  });

  test('fromJson throws on invalid amount', () {
    expect(
      () => Account.fromJson({
        'id': '1',
        'name': 'John Doe',
        'phone': '+1234567890',
        'email': 'john@example.com',
        'amount': 'not-a-number',
        'dueDate': DateTime(2026, 5, 10).toIso8601String(),
        'status': 'Pending',
        'lastContactDate': DateTime(2026, 5, 1).toIso8601String(),
      }),
      throwsA(isA<AccountValidationException>()),
    );
  });
}
