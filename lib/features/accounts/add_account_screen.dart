import 'account_model.dart';
import 'account_repository.dart';

class AddAccountController {
  final AccountRepository repository;

  AddAccountController(this.repository);

  void addAccount({
    required String id,
    required String name,
    required String phone,
    required String email,
    required double amount,
    required DateTime dueDate,
    required String status,
    required DateTime lastContactDate,
  }) {
    final account = Account(
      id: id,
      name: name,
      phone: phone,
      email: email,
      amount: amount,
      dueDate: dueDate,
      status: status,
      lastContactDate: lastContactDate,
    );

    repository.addAccount(account);
  }

  void updateAccount(Account account) {
    repository.updateAccount(account);
  }
}