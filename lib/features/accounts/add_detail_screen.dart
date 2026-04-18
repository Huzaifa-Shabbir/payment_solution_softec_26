import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'account_model.dart';
import 'account_repository.dart';
import 'add_account_screen.dart';
import 'account_repository_helpers.dart';
import '../core/Theme.dart';
import '../../core/utils/state_Management.dart';

class AccountDetailScreen extends StatelessWidget {
  final Account account;
  const AccountDetailScreen({super.key, required this.account});

  String _safeString(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;
  String _safeDate(DateTime? d) {
    if (d == null) return '—';
    try {
      return d.toLocal().toString().split(' ').first;
    } catch (_) {
      return d.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AccountRepository();
    final colors = AppColors();
    final textTheme = Theme.of(context).textTheme;
    final store = AccountStoreProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
        actions: [
          // If the account is marked done, show a green check instead of the options menu.
          account.isPaid
              ? const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 28),
                )
              : PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final res = await context.pushNamed<bool>('addAccount', extra: account);
                      if (res == true) {
                        // signal parent to refresh
                        context.pop(true);
                      }
                    } else if (v == 'done') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Mark as done'),
                          content: Text('Mark ${account.name} as paid/done?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark Done')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await store.markDone(account);
                          context.pop(true);
                        } catch (e) {

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark done: $e')));
                        }
                      }
                    } else if (v == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete account'),
                          content: Text('Are you sure you want to delete ${account.name}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await store.deleteAccount(account.id);
                          context.pop(true);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'done', child: Text('Mark as Done')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            ListTile(title: const Text('Name'), subtitle: Text(_safeString(account.name), style: textTheme.bodyLarge)),
            ListTile(title: const Text('Phone'), subtitle: Text(_safeString(account.phone), style: textTheme.bodyLarge)),
            ListTile(title: const Text('Email'), subtitle: Text(_safeString(account.email), style: textTheme.bodyLarge)),
            ListTile(title: const Text('Amount'), subtitle: Text(account.amount.toStringAsFixed(2), style: textTheme.bodyLarge)),
            ListTile(title: const Text('Due Date'), subtitle: Text(_safeDate(account.dueDate), style: textTheme.bodyLarge)),
            ListTile(title: const Text('Status'), subtitle: Text(_safeString(account.computedStatus), style: textTheme.bodyLarge)),
            ListTile(title: const Text('Last Contact'), subtitle: Text(_safeDate(account.lastContactDate), style: textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}
