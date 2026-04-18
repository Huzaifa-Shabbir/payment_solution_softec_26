import 'account_model.dart';
import 'account_repository.dart';

class AccountListController {
  final AccountRepository repository;

  AccountListController(this.repository);

  // READ ALL (FIXED)
  Future<List<Account>> fetchAccounts() async {
    return await repository.getAllAccounts();
  }

  // DELETE (FIXED)
  Future<void> deleteAccount(String id) async {
    await repository.deleteAccount(id);
  }
}