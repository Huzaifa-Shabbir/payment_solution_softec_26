import 'package:flutter/material.dart';
import 'account_model.dart';
import 'account_repository.dart';
import 'add_account_screen.dart';
import 'add_detail_screen.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen>
    with SingleTickerProviderStateMixin {
  final AccountRepository _repo = AccountRepository();
  late Future<List<Account>> _futureAccounts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _futureAccounts = _repo.getAll();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteAccount(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text('Are you sure you want to delete this account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.delete(id);
      _showSuccess('Account deleted');
      _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _openAdd([Account? account]) async {
    final sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    );

    bool? result;
    try {
      result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        transitionAnimationController: sheetController,
        builder: (_) => AddAccountScreen(account: account, asBottomSheet: true),
      );
    } finally {
      sheetController.dispose();
    }

    if (result == true && mounted) {
      _load();
      _showSuccess(account == null ? 'Account added successfully' : 'Account updated successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      body: FutureBuilder<List<Account>>(
        future: _futureAccounts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) {
            return const Center(child: Text('No accounts yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final acc = accounts[index];
              return ListTile(
                title: Text(acc.name),
                subtitle: Text('${acc.email} • ${acc.phone}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _openAdd(acc);
                    } else if (value == 'delete') {
                      await _deleteAccount(acc.id);
                    } else if (value == 'details') {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(account: acc)));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'details', child: Text('Details')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(account: acc))),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

