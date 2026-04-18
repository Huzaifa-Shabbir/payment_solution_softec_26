import 'account_model.dart';
import 'account_repository.dart';

class AccountListController {
  final AccountRepository repository;

  AccountListController(this.repository);

  List<Account> fetchAccounts() {
    return repository.getAllAccounts();
  }

  void deleteAccount(String id) {
    repository.deleteAccount(id);
  }
}