import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'account_model.dart';
import 'account_repository.dart';
import 'add_account_screen.dart';
import 'add_detail_screen.dart';
import 'account_repository_helpers.dart';
import '../core/Theme.dart';
import '../../core/utils/state_Management.dart';


class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen>
    with SingleTickerProviderStateMixin {
  // UI only uses the global store
  late AccountStore store;

   @override
   void initState() {
     super.initState();
     // load handled globally; get store in didChangeDependencies
   }

   @override
   void didChangeDependencies() {
     super.didChangeDependencies();
     store = AccountStoreProvider.of(context);
   }

   void _reloadFromStore() async {
     await store.load();
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
      await store.deleteAccount(id);
      _showSuccess('Account deleted');
      _reloadFromStore();
     } catch (e) {
       _showError(e.toString());
     }
   }

   Future<void> _openAdd([Account? account]) async {
    final res = await context.pushNamed<bool>('addAccount', extra: {'account': account, 'asBottomSheet': true});
    if (res == true && mounted) {
      await store.load();
      _showSuccess(account == null ? 'Account added successfully' : 'Account updated successfully');
    }
   }

   @override
   Widget build(BuildContext context) {
     final colors = AppColors();
    final store = AccountStoreProvider.of(context);
    final accounts = store.accounts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      body: store.loading
          ? const Center(child: CircularProgressIndicator())
          : accounts.isEmpty
              ? const Center(child: Text('No accounts yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final acc = accounts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(acc.name, style: Theme.of(context).textTheme.bodyLarge),
                        subtitle: Text('${acc.email} • ${acc.phone}', style: Theme.of(context).textTheme.bodyMedium),
                        trailing: acc.isPaid
                            ? const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.check_circle, color: Colors.green, size: 28),
                              )
                            : PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _openAdd(acc);
                                  } else if (value == 'delete') {
                                    await _deleteAccount(acc.id);
                                  } else if (value == 'details') {
                                    await context.pushNamed('accountDetail', extra: acc);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'details', child: Text('Details')),
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                        onTap: () => context.pushNamed('accountDetail', extra: acc),
                      ),
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
