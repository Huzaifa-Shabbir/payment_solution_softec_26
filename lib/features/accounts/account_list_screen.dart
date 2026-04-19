import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'account_model.dart';
import 'account_repository.dart';
import 'add_account_screen.dart';
import 'account_repository_helpers.dart';
import '../core/Theme.dart';
import '../../core/utils/state_Management.dart';
import 'accounts_snackbar.dart';
import 'package:intl/intl.dart';


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

   List<Account> _sortedForDisplay(List<Account> raw) {
     final now = DateTime.now();
     final out = List<Account>.from(raw);
     int rank(Account a) {
       if (!a.isPaid && a.dueDate.isBefore(now)) return 0;
       if (!a.isPaid && !a.dueDate.isBefore(now)) return 1;
       return 2;
     }

     out.sort((a, b) {
       final ra = rank(a), rb = rank(b);
       if (ra != rb) return ra - rb;
       if (ra == 0 || ra == 1) return a.dueDate.compareTo(b.dueDate);
       return a.name.toLowerCase().compareTo(b.name.toLowerCase());
     });
     return out;
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
     AccountsSnackBar.showError(context, message);
   }

   void _showSuccess(String message) {
     AccountsSnackBar.showSuccess(context, message);
   }

   Future<void> _deleteAccount(String id) async {
     // Styled delete confirmation dialog
     final confirm = await showDialog<bool>(
       context: context,
       builder: (_) => Dialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
         backgroundColor: Colors.white,
         child: Padding(
           padding: const EdgeInsets.all(20),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                 child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 36),
               ),
               const SizedBox(height: 16),
               Text('Delete account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
               const SizedBox(height: 10),
               const Text('Are you sure you want to delete this account? This action cannot be undone.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
               const SizedBox(height: 24),
               Row(
                 children: [
                   Expanded(
                     child: OutlinedButton(
                       onPressed: () => Navigator.pop(context, false),
                       style: OutlinedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         side: BorderSide(color: Colors.grey.shade300),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       ),
                       child: const Text('Cancel'),
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: ElevatedButton(
                       onPressed: () => Navigator.pop(context, true),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.red.shade700,
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                         elevation: 3,
                       ),
                       child: const Text('Delete'),
                     ),
                   ),
                 ],
               ),
             ],
           ),
         ),
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
     // show only paid creditors on this screen
     final paidOnly = store.accounts.where((a) => a.isPaid).toList();
     final accounts = _sortedForDisplay(paidOnly);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paid Credits'),
      ),
      body: store.loading
          ? const Center(child: CircularProgressIndicator())
          : accounts.isEmpty
              ? const Center(child: Text('No Paid Creditors yet.'))
              : RefreshIndicator(
                  onRefresh: () async => _reloadFromStore(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final acc = accounts[index];
                      final overdue = !acc.isPaid && acc.dueDate.isBefore(DateTime.now());
                      final initials = acc.name.isNotEmpty
                          ? acc.name.trim().split(' ').map((s) => s.isEmpty ? '' : s[0]).take(2).join()
                          : '?';

                      return Dismissible(
                        key: ValueKey(acc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete account'),
                              content: Text('Delete "${acc.name}"? This action cannot be undone.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await store.deleteAccount(acc.id);
                              _showSuccess('Account deleted');
                              return true;
                            } catch (e) {
                              _showError('Delete failed: $e');
                              return false;
                            }
                          }
                          return false;
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.pushNamed('accountDetail', extra: acc),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: overdue ? Colors.red.shade50 : Colors.blue.shade50,
                                    child: Text(initials.toUpperCase(), style: TextStyle(color: overdue ? Colors.red.shade700 : Colors.blue.shade700, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(acc.name, style: Theme.of(context).textTheme.titleMedium)),
                                            const SizedBox(width: 8),
                                            if (acc.isPaid)
                                              Chip(
                                                label: const Text('Paid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                                backgroundColor: Colors.green.shade700,
                                              )
                                            else
                                              Chip(
                                                label: Text(
                                                  acc.dueDate.isBefore(DateTime.now()) ? 'Overdue' : 'Pending',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                                ),
                                                backgroundColor: acc.dueDate.isBefore(DateTime.now()) ? Colors.red.shade600 : Colors.orange.shade700,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          acc.email.isNotEmpty ? acc.email : acc.phone,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('\$${NumberFormat('#,##0.00').format(acc.amount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text(DateFormat.yMMMd().format(acc.dueDate), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _openAdd(acc);
                                            await store.load();
                                          } else if (value == 'delete') {
                                            await _deleteAccount(acc.id);
                                          } else if (value == 'details') {
                                            await context.pushNamed('accountDetail', extra: acc);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(value: 'details', child: Text('Details')),
                                          if (!acc.isPaid) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(),
        backgroundColor: colors.appbar_Color,
        child: const Icon(Icons.add),
      ),
    );
   }
 }
