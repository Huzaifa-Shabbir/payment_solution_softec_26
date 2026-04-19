import 'package:flutter/material.dart';
import '../../features/accounts/account_repository.dart';
import '../../features/accounts/account_model.dart';
import '../../features/accounts/account_repository_helpers.dart';

/// Central account data store used across the app.
/// - holds loaded accounts
/// - performs sync/load/add/update/delete via repository
/// - exposes helpers for filtering and computed balance
class AccountStore extends ChangeNotifier {
  final AccountRepository _repo = AccountRepository();

  List<Account> accounts = [];
  bool loading = false;
  double balance = 0.0;

  AccountStore();

  Future<void> init() async {
    await load();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      accounts = await _repo.getAll();
      _computeBalance();
    } catch (e) {
      accounts = [];
      balance = 0.0;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Best-effort sync with remote then reload local list.
  Future<void> sync() async {
    loading = true;
    notifyListeners();
    try {
      try {
        await _repo.syncFromSupabase();
      } catch (_) {}
      accounts = await _repo.getAll();
      _computeBalance();
    } catch (e) {
      // ignore, keep whatever we have
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addAccount(Account a) async {
    loading = true;
    notifyListeners();
    try {
      await _repo.add(a);
      try {
        await _repo.upsertLocal(a);
      } catch (_) {}
      accounts = await _repo.getAll();
      _computeBalance();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateAccount(Account a) async {
    loading = true;
    notifyListeners();
    try {
      await _repo.update(a);
      try {
        await _repo.upsertLocal(a);
      } catch (_) {}
      accounts = await _repo.getAll();
      _computeBalance();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount(String id) async {
    loading = true;
    notifyListeners();
    try {
      await _repo.delete(id);
      try {
        await _repo.deleteLocal(id);
      } catch (_) {}
      accounts = await _repo.getAll();
      _computeBalance();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Mark paid/done
  Future<void> markDone(Account a) async {
    // Ensure marking as done sets both the paid flag and the status consistently.
    final updated = a.copyWith(
      isPaid: true,
      status: 'Done',
      lastContactDate: DateTime.now(),
    );
    await updateAccount(updated);
  }

  /// Filtering & sorting logic reused from dashboard -> returns a new list.
  List<Account> filteredAccounts(String search, String filter) {
    final q = search.trim().toLowerCase();
    final tmp = accounts.where((a) {
      final matchesSearch = q.isEmpty ||
          a.name.toLowerCase().contains(q) ||
          a.email.toLowerCase().contains(q) ||
          a.phone.toLowerCase().contains(q);
      final matchesFilter = filter == 'All' || a.computedStatus.toLowerCase() == filter.toLowerCase();
      return matchesSearch && matchesFilter;
    }).toList();

    tmp.sort((a, b) {
      int priority(String s) {
        final v = s.toLowerCase();
        if (v.contains('over')) return 0;
        if (v.contains('pend')) return 1;
        if (v.contains('done')) return 2;
        return 3;
      }

      final pa = priority(a.computedStatus);
      final pb = priority(b.computedStatus);
      if (pa != pb) return pa - pb;

      final now = DateTime.now();
      if (pa == 0) {
        final daysA = now.difference(a.dueDate).inDays;
        final daysB = now.difference(b.dueDate).inDays;
        return daysB.compareTo(daysA);
      }
      if (pa == 1) {
        return a.dueDate.compareTo(b.dueDate);
      }
      if (pa == 2) {
        return b.lastContactDate.compareTo(a.lastContactDate);
      }
      return a.dueDate.compareTo(b.dueDate);
    });

    return tmp;
  }

  void _computeBalance() {
    final now = DateTime.now();
    double overdueSum = 0.0;
    double doneSum = 0.0;
    for (final a in accounts) {
      if (!a.isPaid && a.dueDate.isBefore(now)) overdueSum += a.amount;
      if (a.isPaid) doneSum += a.amount;
    }
    final offset = doneSum < overdueSum ? doneSum : overdueSum;
    final remainingOverdue = overdueSum - offset;
    balance = -remainingOverdue;
  }
}

/// InheritedNotifier to expose AccountStore via AccountStoreProvider.of(context)
class AccountStoreProvider extends InheritedNotifier<AccountStore> {
  const AccountStoreProvider({required AccountStore store, required Widget child})
      : super(notifier: store, child: child);

  static AccountStore of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AccountStoreProvider>();
    if (provider == null) {
      throw FlutterError('AccountStoreProvider not found in context');
    }
    return provider.notifier!;
  }
}
