import 'dart:convert';
import 'account_model.dart';
import '../../services/local_storage.dart';

class AccountRepository {
  static const String _key = 'accounts';

  Future<List<Account>> getAll() async {
    try {
      final raw = LocalStorage.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load accounts: $e');
    }
  }

  Future<void> saveAll(List<Account> accounts) async {
    try {
      final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await LocalStorage.setString(_key, encoded);
    } catch (e) {
      throw Exception('Failed to save accounts: $e');
    }
  }

  Future<Account> add(Account account) async {
    try {
      final list = await getAll();
      list.add(account);
      await saveAll(list);
      return account;
    } catch (e) {
      throw Exception('Failed to add account: $e');
    }
  }

  Future<void> update(Account account) async {
    try {
      final list = await getAll();
      final idx = list.indexWhere((a) => a.id == account.id);
      if (idx == -1) throw Exception('Account not found');
      list[idx] = account;
      await saveAll(list);
    } catch (e) {
      throw Exception('Failed to update account: $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      final list = await getAll();
      final newList = list.where((a) => a.id != id).toList();
      await saveAll(newList);
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}

