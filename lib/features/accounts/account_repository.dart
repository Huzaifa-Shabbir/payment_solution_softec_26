import 'dart:convert';
import 'account_model.dart';
import '../../services/local_storage.dart';

class AccountRepository {
  static const String _key = 'accounts';

  String _humanizeError(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }

  Future<List<Account>> getAll() async {
    try {
      final raw = LocalStorage.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final accounts = <Account>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        try {
          accounts.add(Account.fromJson(item));
        } on AccountValidationException {
          // Skip malformed records so one bad entry does not block the whole list.
          continue;
        }
      }
      return accounts;
    } catch (e) {
      throw Exception('Failed to load accounts: ${_humanizeError(e)}');
    }
  }

  Future<void> saveAll(List<Account> accounts) async {
    try {
      final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await LocalStorage.setString(_key, encoded);
    } catch (e) {
      throw Exception('Failed to save accounts: ${_humanizeError(e)}');
    }
  }

  Future<Account> add(Account account) async {
    try {
      final list = await getAll();
      final exists = list.any((a) => a.id == account.id);
      if (exists) {
        throw Exception('Account already exists.');
      }
      list.add(account);
      await saveAll(list);
      return account;
    } on AccountValidationException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to add account: ${_humanizeError(e)}');
    }
  }

  Future<void> update(Account account) async {
    try {
      final list = await getAll();
      final idx = list.indexWhere((a) => a.id == account.id);
      if (idx == -1) throw Exception('Account not found');
      list[idx] = account;
      await saveAll(list);
    } on AccountValidationException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update account: ${_humanizeError(e)}');
    }
  }

  Future<void> delete(String id) async {
    try {
      if (id.trim().isEmpty) {
        throw Exception('Account id is required.');
      }
      final list = await getAll();
      final newList = list.where((a) => a.id != id).toList();
      await saveAll(newList);
    } catch (e) {
      throw Exception('Failed to delete account: ${_humanizeError(e)}');
    }
  }
}
