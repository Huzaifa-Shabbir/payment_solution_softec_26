import 'account_model.dart';
import 'account_repository.dart';

class AccountDetailController {
  final AccountRepository repository;

  AccountDetailController(this.repository);

  // READ (FIXED)
  Future<Account?> getAccount(String id) async {
    return await repository.getAccountById(id);
  }

  // UPDATE (FIXED)
  Future<void> updateAccount(Account updatedAccount) async {
    await repository.updateAccount(updatedAccount);
  }
}