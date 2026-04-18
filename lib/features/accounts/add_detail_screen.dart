import 'account_model.dart';
import 'account_repository.dart';

class AccountDetailController {
  final AccountRepository repository;

  AccountDetailController(this.repository);

  Account? getAccount(String id) {
    return repository.getAccountById(id);
  }

  void updateAccount(Account updatedAccount) {
    repository.updateAccount(updatedAccount);
  }
}