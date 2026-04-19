import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../accounts/account_model.dart';
import '../accounts/add_account_screen.dart'; 

import '../core/Theme.dart';
import '../../core/utils/state_Management.dart';
import 'account_tile.dart'; // <-- added import
import '../accounts/accounts_snackbar.dart';

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

   // Sort accounts: overdue (not paid & dueDate < now) first,
   // then pending (not paid & dueDate >= now), then others (paid).
   List<Account> _sortAccounts(List<Account> list) {
     final now = DateTime.now();
     final out = List<Account>.from(list);
     int rank(Account a) {
       if (!a.isPaid && a.dueDate.isBefore(now)) return 0;
       if (!a.isPaid && !a.dueDate.isBefore(now)) return 1;
       return 2;
     }
     out.sort((a, b) {
       final ra = rank(a), rb = rank(b);
       if (ra != rb) return ra - rb;
       // tie-break: for overdue/pending sort by dueDate (earlier first), otherwise by name
       if (ra == 0 || ra == 1) return a.dueDate.compareTo(b.dueDate);
       return a.name.toLowerCase().compareTo(b.name.toLowerCase());
     });
     return out;
   }

   void _applyFilters() {
    final store = AccountStoreProvider.of(context);
    // If store is still loading, preserve the current filtered list to avoid wiping UI
    if (store.loading) {
      if (mounted) setState(() => _loading = true);
      return;
    }

    final now = DateTime.now();
    // start from all accounts in store (defensive copy)
    List<Account> accounts = List<Account>.from(store.accounts);

    // apply search (name / email / phone)
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      accounts = accounts.where((a) {
        return a.name.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q) ||
            a.phone.toLowerCase().contains(q);
      }).toList();
    }

    // apply filter tag
    List<Account> result;
    switch (_filter) {
      case 'Overdue':
        result = accounts.where((a) => !a.isPaid && a.dueDate.isBefore(now)).toList();
        break;
      case 'Pending':
        result = accounts.where((a) => !a.isPaid && !a.dueDate.isBefore(now)).toList();
        break;
      case 'All':
      default:
        result = accounts;
        break;
    }

    // sort result: overdue -> pending -> others
    result = _sortAccounts(result);

    if (mounted) {
      setState(() {
        _filtered = result;
        _animFrom = _balance;
        _balance = store.balance;
        _loading = store.loading;
      });
    }
   }

   Color _colorForStatus(String status) {
     final s = status.toLowerCase();
     if (s.contains('over')) return Colors.red.shade600;
     if (s.contains('pend')) return Colors.orange.shade700;
     if (s.contains('done')) return Colors.green.shade600;
     return Colors.grey;
   }

   Widget _buildTile(Account a) {
     final store = AccountStoreProvider.of(context);
     return AccountTile(
       account: a,
       onTap: () async {
         // open the redesigned follow-up / account detail screen
         final res = await Navigator.of(context).push<bool>(
           MaterialPageRoute(builder: (_) => AccountFollowUpScreen(account: a)),
         );
         if (res == true) {
           await store.load();
           _applyFilters();
         }
       },
       onEdit: () async {
         // open add/edit as bottom sheet and pass the account for prefill
         final res = await context.pushNamed<bool>('addAccount', extra: {'asBottomSheet': true, 'account': a});
         if (res == true) {
           await store.load();
           _applyFilters();
           AccountsSnackBar.showSuccess(context, 'Account saved');
         }
       },
       onMarkDone: () async {
         // Styled confirmation dialog (single dialog)
         final confirmed = await showDialog<bool>(
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
                     decoration: BoxDecoration(
                       color: Colors.green.withOpacity(0.1),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 36),
                   ),
                   const SizedBox(height: 16),
                   Text('Mark as Paid?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 10),
                   Text('Do you want to mark\n"${a.name}" as paid?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
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
                             backgroundColor: Colors.green.shade700,
                             padding: const EdgeInsets.symmetric(vertical: 12),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                             elevation: 3,
                           ),
                           child: const Text('Mark Done'),
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
             ),
           ),
         );
         if (confirmed == true) {
           try {
             // mark as done by updating account fields and persisting
             final updated = a.copyWith(isPaid: true, status: 'Done');
             await store.updateAccount(updated);
             _applyFilters();
             AccountsSnackBar.showSuccess(context, 'Marked as done');
           } catch (e) {
             AccountsSnackBar.showError(context, 'Failed to mark done: $e');
           }
         }
       },
       onDelete: () async {
         // Styled delete confirmation (single dialog)
         final confirmed = await showDialog<bool>(
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
                   Text('Are you sure you want to delete "${a.name}"? This action cannot be undone.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
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
         if (confirmed == true) {
           try {
             await store.deleteAccount(a.id);
             _applyFilters();
             AccountsSnackBar.showSuccess(context, 'Account deleted');
           } catch (e) {
             AccountsSnackBar.showError(context, 'Delete failed: $e');
           }
         }
       },
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
     final res = await context.pushNamed<bool>('addAccount', extra: {'asBottomSheet': true, 'account': null});
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

   // Helper: format exact amount (no $ sign, no "k" abbreviation)
   String _compactCurrency(double v) {
     final fmtNoSymbol = NumberFormat('#,##0.00');
     return fmtNoSymbol.format(v);
   }
   Widget _summaryCard({
     required Color bg,
     required Color iconColor,
     required IconData icon,
     required String title,
     required String value,
   }) {
     return SizedBox(
       width: 160, // ✅ fixed width avoids overflow chaos
       child: Container(
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: bg,
           borderRadius: BorderRadius.circular(12),
         ),
         child: Row(
           children: [
             Container(
               decoration: BoxDecoration(
                 color: iconColor.withOpacity(0.15),
                 shape: BoxShape.circle,
               ),
               padding: const EdgeInsets.all(10),
               child: Icon(icon, color: iconColor, size: 22),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(title,
                       style: const TextStyle(
                           fontSize: 12, color: Colors.black54)),
                   const SizedBox(height: 4),
                   Text(value,
                       style: const TextStyle(
                           fontSize: 16, fontWeight: FontWeight.bold)),
                 ],
               ),
             )
           ],
         ),
       ),
     );
   }
   Widget _filterButton(String key, Color dotColor, String label) {
     final selected = _filter == key ||
         (_filter == 'All' && key == 'All');

     return InkWell(
       onTap: () {
         setState(() {
           _filter = switch (key) {
             'Overdue' => 'Overdue',
             'Pending' => 'Pending',
             _ => 'All',
           };
           _applyFilters();
         });
       },
       borderRadius: BorderRadius.circular(8),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
         margin: const EdgeInsets.only(right: 8),
         decoration: BoxDecoration(
           color: selected ? Colors.grey.withOpacity(0.12) : Colors.transparent,
           borderRadius: BorderRadius.circular(8),
           border: selected
               ? Border.all(color: Colors.grey.withOpacity(0.2))
               : null,
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Container(
               width: 10,
               height: 10,
               decoration: BoxDecoration(
                   color: dotColor, shape: BoxShape.circle),
             ),
             const SizedBox(width: 8),
             Text(label,
                 style: const TextStyle(fontWeight: FontWeight.w600)),
           ],
         ),
       ),
     );
   }
   Widget _buildTopSummary() {
     final store = AccountStoreProvider.of(context);
     final now = DateTime.now();
     final accounts = store.accounts;

     final totalOverdue = accounts
         .where((a) => !a.isPaid && a.dueDate.isBefore(now))
         .fold<double>(0.0, (p, e) => p + e.amount);

     Widget _filterButton(String key, Color dotColor, String label) {
       final selected = (_filter == key) || (_filter == 'All' && key == 'All');

       return GestureDetector(
         onTap: () {
           setState(() {
             if (key == 'Overdue') _filter = 'Overdue';
             else if (key == 'Pending') _filter = 'Pending';
             else _filter = 'All';

             _applyFilters();
           });
         },
         child: Container(
           // removed external right margin and reduced horizontal padding to avoid Row overflow
           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
           margin: EdgeInsets.zero,
           decoration: BoxDecoration(
             color: selected ? Colors.grey.withOpacity(0.3) : Colors.grey.withOpacity(0.05),
             borderRadius: BorderRadius.circular(15),
           ),
           child: Row(
             children: [
               Container(
                 width: 10,
                 height: 10,
                 decoration: BoxDecoration(
                   color: dotColor,
                   shape: BoxShape.circle,
                 ),
               ),
               const SizedBox(width: 8),
               Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
             ],
           ),
         ),
       );
     }

     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           /// 🔥 BIG OVERDUE CARD
           Container(
             width: double.infinity,
             padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 22),
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 colors: [
                   Colors.blue.shade50,
                   Colors.blue.shade100,
                 ],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               ),
               borderRadius: BorderRadius.circular(24),
               boxShadow: [
                 BoxShadow(
                   color: Colors.blue.withOpacity(0.15),
                   blurRadius: 20,
                   offset: const Offset(0, 8),
                 ),
               ],
             ),
             child: Row(
               children: [
                 /// ICON
                 Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: Colors.blue.shade600.withOpacity(0.15),
                     shape: BoxShape.circle,
                   ),
                   child: Icon(
                     Icons.attach_money,
                     color: Colors.blue.shade700,
                     size: 32,
                   ),
                 ),

                 const SizedBox(width: 16),

                 /// TEXT
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       'OVERDUE PAYMENTS',
                       style: TextStyle(
                         fontSize: 14,
                         letterSpacing: 1.2,
                         color: Colors.blueGrey.shade600,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     const SizedBox(height: 8),
                     Text(
                       _compactCurrency(totalOverdue),
                       style: TextStyle(
                         fontSize: 32,
                         fontWeight: FontWeight.bold,
                         color: Colors.red,
                       ),
                     ),
                   ],
                 )
               ],
             ),
           ),

           const SizedBox(height: 16),

           Container(

               child:Row(
                 children: [
                   Expanded(child: _filterButton('All', Colors.blue, 'All')),
                   const SizedBox(width: 8),
                   Expanded(child: _filterButton('Overdue', Colors.red, 'Overdue')),
                   const SizedBox(width: 8),
                   Expanded(child: _filterButton('Pending', Colors.orange, 'Pending')),
                 ],
               )
           ),
         ],
       ),
     );
   }
   @override
   Widget build(BuildContext context) {
     final colors = AppColors();
     final textTheme = Theme.of(context).textTheme;
     // make sure filters reflect current store state (initial application is done in initState).
     // Avoid running _applyFilters every build to prevent transient clearing of the list.

     return Scaffold(
       backgroundColor: colors.Background,
       appBar: AppBar(
         backgroundColor: colors.appbar_Color,
         elevation: 0,
         titleSpacing: 0,
         title: Row(
           children: [
             /// 🔥 ICON

             const SizedBox(width: 14),
             Container(
               padding: const EdgeInsets.all(6),
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.15),
                 borderRadius: BorderRadius.circular(10),
               ),
               child: const Icon(
                 Icons.account_balance_wallet,
                 color: Colors.white,
                 size: 22,
               ),
             ),

             const SizedBox(width: 10),

             /// 🔥 TEXT
             const Text(
               "SmartPay",
               style: TextStyle(
                 fontSize: 20,
                 fontWeight: FontWeight.w700,
                 letterSpacing: 0.5,
                 // 👇 if using Google Fonts later, replace here
                 // fontFamily: 'Poppins',
               ),
             ),
           ],
         ),
       ),
       body: Column(
         children: [
           _buildTopSummary(),
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
   Widget _buildSearchFilter() {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
       child: Row(
         children: [
           Expanded(
             child: TextField(
               decoration:  InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customers', hintStyle: TextStyle(
                 color: Colors.grey.shade600, // 👈 lighter
               ),),
               onChanged: (v) {
                 _search = v;
                 _applyFilters();
               },
             ),
           ),

         ],
       ),
     );
   }
 }
