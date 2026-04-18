import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../accounts/account_model.dart';
import '../accounts/account_repository.dart';
import '../accounts/add_account_screen.dart';
import '../accounts/account_list_screen.dart';
import '../accounts/add_detail_screen.dart';
import 'package:payment_solution_softec_26/features/core/Theme.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  final AccountRepository _repo = AccountRepository();
  final NumberFormat _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  List<Account> _accounts = [];
  List<Account> _filtered = [];
  String _search = '';
  String _filter = 'All';
  double _balance = 0.0;
  double _animFrom = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    try {
      final list = await _repo.getAll();
      _accounts = list;
    } catch (e) {
      _accounts = [];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load accounts: $e')));
    } finally {
      _applyFilters();
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _search.trim().toLowerCase();
    final tmp = _accounts.where((a) {
      final matchesSearch = q.isEmpty ||
          a.name.toLowerCase().contains(q) ||
          a.email.toLowerCase().contains(q) ||
          a.phone.toLowerCase().contains(q);
      final matchesFilter = _filter == 'All' || a.computedStatus.toLowerCase() == _filter.toLowerCase();
      return matchesSearch && matchesFilter;
    }).toList();

    tmp.sort((a, b) {
      // status priority: Overdue (0) -> Pending (1) -> Done (2)
      int priority(String s) {
        final v = s.toLowerCase();
        if (v.contains('over')) return 0;
        if (v.contains('pend')) return 1;
        if (v.contains('done')) return 2;
        return 3;
      }

      final sa = a.computedStatus;
      final sb = b.computedStatus;
      final pa = priority(sa);
      final pb = priority(sb);
      if (pa != pb) return pa - pb;

      // If both overdue -> most overdue first (higher daysLate first)
      final now = DateTime.now();
      if (pa == 0) {
        final daysA = now.difference(a.dueDate).inDays;
        final daysB = now.difference(b.dueDate).inDays;
        return daysB.compareTo(daysA); // descending
      }

      // If both pending -> earliest due date first
      if (pa == 1) {
        return a.dueDate.compareTo(b.dueDate);
      }

      // Done -> most recently contacted first
      if (pa == 2) {
        return b.lastContactDate.compareTo(a.lastContactDate);
      }

      return a.dueDate.compareTo(b.dueDate);
    });

    // compute balance:
    // - Overdue (unpaid & past due) contribute negatively.
    // - Done (isPaid) amounts only offset overdue, up to the overdue total.
    // - Done must NOT create a positive balance.
    final now = DateTime.now();
    double overdueSum = 0.0;
    double doneSum = 0.0;
    for (final a in _accounts) {
      if (!a.isPaid && a.dueDate.isBefore(now)) {
        overdueSum += a.amount;
      }
      if (a.isPaid) {
        doneSum += a.amount;
      }
    }
    final double offset = doneSum < overdueSum ? doneSum : overdueSum;
    final double remainingOverdue = overdueSum - offset; // >= 0
    final double bal = -remainingOverdue; // negative or zero; never positive

    setState(() {
      _filtered = tmp;
      _animFrom = _balance;
      _balance = bal;
    });
  }

  Color _colorForStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('over')) return Colors.red.shade600;
    if (s.contains('pend')) return Colors.orange.shade700;
    if (s.contains('done')) return Colors.green.shade600;
    return Colors.grey;
  }

  Widget _buildTile(Account a) {
    final color = _colorForStatus(a.computedStatus);
    final due = DateFormat.yMMMd().format(a.dueDate);

    // Choose card background:
    // - Overdue -> light red
    // - Done -> light green
    // - Pending (and others) -> default card color
    final statusLower = a.computedStatus.toLowerCase();
    final cardBg = statusLower.contains('over')
        ? Colors.red.shade50
        : statusLower.contains('done')
            ? Colors.green.shade50
            : Theme.of(context).cardColor;

    return Card(
      color: cardBg,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: ListTile(
        title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${_fmt.format(a.amount)} • Due: $due'),
        // If account is paid/done show a green check icon instead of the three-dots menu
        trailing: a.isPaid
            ? const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.check_circle, color: Colors.green, size: 28),
              )
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'edit') {
                    // open add/edit screen via go_router
                    final res = await context.pushNamed<bool>('addAccount', extra: a);
                    if (res == true) {
                      await _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account saved')));
                    }
                  } else if (value == 'done') {
                    // mark done flow
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Mark as done'),
                        content: Text('Mark ${a.name} as paid/done?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark Done')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        final updated = a.copyWith(isPaid: true, lastContactDate: DateTime.now());
                        await _repo.update(updated);
                        await _refresh();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as done')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark done: $e')));
                      }
                    }
                  } else if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete account'),
                        content: Text('Are you sure you want to delete ${a.name}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        await _repo.delete(a.id);
                        await _refresh();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deleted')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                      }
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'done', child: Text('Mark as Done')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
        onTap: () async {
          final res = await context.pushNamed<bool>('accountDetail', extra: a);
          if (res == true) _refresh();
        },
      ),
    );
  }


  Widget _buildList() {
    if (_loading) return const Expanded(child: Center(child: CircularProgressIndicator()));
    if (_filtered.isEmpty) return const Expanded(child: Center(child: Text('No customers found.')));
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 8),
          itemCount: _filtered.length,
          itemBuilder: (c, i) => _buildTile(_filtered[i]),
        ),
      ),
    );
  }

  void _onAddPressed() async {
    // navigate to add screen using go_router and let AddAccountScreen render asBottomSheet
    final res = await context.pushNamed<bool>('addAccount', extra: {'asBottomSheet': true});
    if (res == true) {
      await _refresh();
    }
  }

  int _selectedIndex = 0;
  void _onNavTap(int idx) async {
    if (idx == 1) {
      await context.pushNamed('accounts');
      await _refresh();
      return;
    }
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors().Background,
      appBar: AppBar(
        title: Text("SmartPay",style:TextStyle(color: AppColors().secondary_Text,fontSize: 24,fontWeight: FontWeight.bold)),
        backgroundColor: AppColors().appbar_Color,
      ),
      body: Column(
        children: [
          _buildBalanceCard(),
          _buildSearchFilter(),
          _buildList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPressed,
        child: const Icon(Icons.add, size: 28),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(icon: Icon(Icons.grid_view, color: _selectedIndex == 0 ? Colors.blue : Colors.grey), onPressed: () => _onNavTap(0)),
              IconButton(icon: Icon(Icons.people, color: _selectedIndex == 1 ? Colors.blue : Colors.grey), onPressed: () => _onNavTap(1)),
              const SizedBox(width: 48), // space for FAB
              IconButton(icon: Icon(Icons.history, color: _selectedIndex == 2 ? Colors.blue : Colors.grey), onPressed: () => _onNavTap(2)),
              IconButton(icon: Icon(Icons.settings, color: _selectedIndex == 3 ? Colors.blue : Colors.grey), onPressed: () => _onNavTap(3)),
            ],
          ),
        ),
      ),
    );
  }

  // re-use existing balance card & search/filter builders
  Widget _buildBalanceCard() {
    final color = _balance < 0 ? Colors.red.shade700 : Colors.green.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Column(
            children: [
              Text('Total Balance', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: _animFrom, end: _balance),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, _) {
                  return Text(
                    _fmt.format(value),
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customers'),
              onChanged: (v) {
                _search = v;
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _filter,
            items: const ['All', 'Overdue', 'Pending', 'Done'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) {
              _filter = v ?? 'All';
              _applyFilters();
            },
          )
        ],
      ),
    );
  }
}
