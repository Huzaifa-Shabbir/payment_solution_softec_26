import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    // balance = (sum of overdue as negative) + (sum of done amounts as positive)
    double bal = 0.0;
    for (final a in _accounts) {
      final s = a.computedStatus.toLowerCase();
      if (s.contains('over')) {
        bal += -a.amount;
      } else if (s.contains('done')) {
        bal += a.amount;
      }
    }

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

  Future<void> _markDone(Account a) async {
    final confirm = await showDialog<bool>(
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
    if (confirm != true) return;

    try {
      final updated = a.copyWith(isPaid: true, lastContactDate: DateTime.now());
      await _repo.update(updated);
      await _refresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as done')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark done: $e')));
    }
  }

  Widget _buildTile(Account a) {
    final color = _colorForStatus(a.computedStatus);
    final due = DateFormat.yMMMd().format(a.dueDate);

    // Choose card background: light red for overdue, default otherwise
    final cardBg = a.computedStatus.toLowerCase().contains('over')
        ? Colors.red.shade50
        : Theme.of(context).cardColor;

    return Card(
      color: cardBg, // <-- apply background color here
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: ListTile(
        title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${_fmt.format(a.amount)} • Due: $due'),
        trailing:
          // Constrain trailing column to its intrinsic size to prevent overflow.
          Column(
            mainAxisSize: MainAxisSize.min, // <-- prevent vertical expansion
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Text(a.computedStatus, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              if (a.computedStatus != 'Done')
                // Limit size of the icon button so it cannot force the Column to expand.
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero, // tighten touch target padding
                    icon: Icon(Icons.check_circle, color: Colors.green.shade600),
                    tooltip: 'Mark as Done',
                    onPressed: () => _markDone(a),
                    splashRadius: 18,
                  ),
                ),
            ],
          ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(account: a))),
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
    final sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    );

    bool? res;
    try {
      res = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        transitionAnimationController: sheetController,
        builder: (_) => const AddAccountScreen(asBottomSheet: true),
      );
    } finally {
      sheetController.dispose();
    }

    if (res == true) {
      await _refresh();
    }
  }

  int _selectedIndex = 0;
  void _onNavTap(int idx) {
    if (idx == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountListScreen())).then((_) => _refresh());
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
