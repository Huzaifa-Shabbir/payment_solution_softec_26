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
  bool _listening = false;

  String _compactCurrency(double value) {
    return NumberFormat('#,##0.00').format(value);
  }

  Widget _buildPaidSummary(double totalPaid) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.green.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade700.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: Colors.green.shade800,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL PAID',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.0,
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _compactCurrency(totalPaid),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // load handled globally; get store in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    store = AccountStoreProvider.of(context);
    if (!_listening) {
      store.addListener(_onStoreChanged);
      _listening = true;
    }
  }

  @override
  void dispose() {
    if (_listening) {
      store.removeListener(_onStoreChanged);
      _listening = false;
    }
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
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
      builder: (dialogCtx) => Dialog(
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
                      onPressed: () => Navigator.pop(dialogCtx, false),
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
                      onPressed: () => Navigator.pop(dialogCtx, true),
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
      _showSuccess('Successfully deleted');
      _reloadFromStore();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _openAdd([Account? account]) async {
    final res = await context.pushNamed<bool>('addAccount', extra: {'account': account, 'asBottomSheet': true});
    if (res == true && mounted) {
      await store.load();
      _showSuccess(account == null ? 'Added successfully' : 'Updated successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    // use the store field (kept up-to-date via listener)
    // show only paid creditors on this screen
    final paidOnly = store.accounts.where((a) => a.isPaid).toList();
    final accounts = _sortedForDisplay(paidOnly);
    final totalPaid = paidOnly.fold<double>(0.0, (sum, account) => sum + account.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paid Credits'),
      ),
      body: store.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async => _reloadFromStore(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          itemCount: accounts.isEmpty ? 2 : accounts.length + 1,
          separatorBuilder: (_, index) => index == 0 ? const SizedBox(height: 14) : const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildPaidSummary(totalPaid);
            }

            if (accounts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text('No paid creditors yet. Tap + to add one.')),
              );
            }

            final acc = accounts[index - 1];
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Delete account'),
                    content: Text('Delete "${acc.name}"? This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await store.deleteAccount(acc.id);
                    _showSuccess('Successfully deleted');
                    return true;
                  } catch (e) {
                    _showError('Delete failed: $e');
                    return false;
                  }
                }
                return false;
              },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1.5,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.pushNamed('accountDetail', extra: acc),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.green.shade50,
                          child: Text(
                            initials.toUpperCase(),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                acc.email.isNotEmpty ? acc.email : acc.phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Due ${DateFormat.yMMMd().format(acc.dueDate)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '\$${NumberFormat('#,##0.00').format(acc.amount)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              color: Colors.white,
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              icon: Icon(
                                Icons.more_vert,
                                color: Colors.grey.shade700,
                                size: 20,
                              ),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _openAdd(acc);
                                  await store.load();
                                } else if (value == 'delete') {
                                  await _deleteAccount(acc.id);
                                }
                              },
                              itemBuilder: (_) => [
                                if (!acc.isPaid) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.red.shade700),
                                      const SizedBox(width: 10),
                                      Text('Delete', style: TextStyle(color: Colors.red.shade700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

