import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../accounts/account_model.dart';

import '../core/Theme.dart';
import '../../core/utils/state_Management.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
   final NumberFormat _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

   // local UI-only state
   List<Account> _filtered = [];
   String _search = '';
   String _filter = 'All';
   double _balance = 0.0;
   double _animFrom = 0.0;
   bool _loading = true;

   @override
   void initState() {
     super.initState();
     // initial data is loaded by the global store in main(), but we still ensure local filters apply
     WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilters());
   }

   Future<void> _refresh() async {
    final store = AccountStoreProvider.of(context);
    await store.sync();
    _applyFilters();
   }

   void _applyFilters() {
    final store = AccountStoreProvider.of(context);
    final tmp = store.filteredAccounts(_search, _filter);
    setState(() {
      _filtered = tmp;
      _animFrom = _balance;
      _balance = store.balance;
      _loading = store.loading;
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
         title: Text(a.name, style: Theme.of(context).textTheme.labelLarge),
         subtitle: Text('${_fmt.format(a.amount)} • Due: $due', style: Theme.of(context).textTheme.bodyMedium),
         trailing: a.isPaid
             ? const Padding(
                 padding: EdgeInsets.only(right: 8.0),
                 child: Icon(Icons.check_circle, color: Colors.green, size: 28),
               )
             : PopupMenuButton<String>(
                 icon: const Icon(Icons.more_vert),
                 onSelected: (value) async {
                   final store = AccountStoreProvider.of(context);
                   if (value == 'edit') {
                     final res = await context.pushNamed<bool>('addAccount', extra: a);
                     if (res == true) {
                       await store.load();
                       _applyFilters();
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account saved')));
                     }
                   } else if (value == 'done') {
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
                         await store.markDone(a);
                         _applyFilters();
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
                         await store.deleteAccount(a.id);
                         _applyFilters();
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
           if (res == true) {
             final store = AccountStoreProvider.of(context);
             await store.load();
             _applyFilters();
           }
         },
       ),
     );
   }


   Widget _buildList() {
    final store = AccountStoreProvider.of(context);
    if (store.loading) return const Expanded(child: Center(child: CircularProgressIndicator()));
    final list = _filtered;
    if (list.isEmpty) return const Expanded(child: Center(child: Text('No customers found.')));
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 8),
          itemCount: list.length,
          itemBuilder: (c, i) => _buildTile(list[i]),
        ),
      ),
    );
   }

   void _onAddPressed() async {
     // navigate to add screen using go_router and let AddAccountScreen render asBottomSheet
     final res = await context.pushNamed<bool>('addAccount', extra: {'asBottomSheet': true});
     if (res == true) {
      final store = AccountStoreProvider.of(context);
      await store.load();
      _applyFilters();
     }
   }

   int _selectedIndex = 0;
   void _onNavTap(int idx) async {
     if (idx == 1) {
       await context.pushNamed('accounts');
       await _refresh();
       return;
     }
     if (idx == 3) {
       // open settings screen via named route
       await context.pushNamed('settings');
       return;
     }
     setState(() => _selectedIndex = idx);
   }

   @override
   Widget build(BuildContext context) {
     final colors = AppColors();
     final textTheme = Theme.of(context).textTheme;
     // make sure filters reflect current store state
     WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilters());

     return Scaffold(
       backgroundColor: colors.Background,
       appBar: AppBar(
         title: Text("SmartPay", style: textTheme.titleLarge?.copyWith(color: colors.secondary_Text)),
         backgroundColor: colors.appbar_Color,
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
               IconButton(icon: Icon(Icons.grid_view, color: _selectedIndex == 0 ? colors.appbar_Color : Colors.grey), onPressed: () => _onNavTap(0)),
               IconButton(icon: Icon(Icons.people, color: _selectedIndex == 1 ? colors.appbar_Color : Colors.grey), onPressed: () => _onNavTap(1)),
               const SizedBox(width: 48),
               IconButton(icon: Icon(Icons.history, color: _selectedIndex == 2 ? colors.appbar_Color : Colors.grey), onPressed: () => _onNavTap(2)),
               IconButton(icon: Icon(Icons.settings, color: _selectedIndex == 3 ? colors.appbar_Color : Colors.grey), onPressed: () => _onNavTap(3)),
             ],
           ),
         ),
       ),
     );
   }

   // re-use existing balance card & search/filter builders
   Widget _buildBalanceCard() {
     final colors = AppColors();
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
