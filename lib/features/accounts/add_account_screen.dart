import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'account_model.dart';
import 'account_repository.dart';
import 'account_repository_helpers.dart';
import '../core/Theme.dart';
import '../../core/utils/state_Management.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'accounts_snackbar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'account_model.dart';
import 'package:flutter/scheduler.dart';
class AddAccountScreen extends StatefulWidget {
  final Account? account;
  final bool asBottomSheet;

  const AddAccountScreen({
    super.key,

    this.account,
    this.asBottomSheet = false,
  });

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _dueDate;
  final AccountRepository _repo = AccountRepository();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      final a = widget.account!;
      _nameCtrl.text = a.name;
      _phoneCtrl.text = a.phone;
      _emailCtrl.text = a.email;
      _amountCtrl.text = a.amount.toString();
      _dueDate = a.dueDate;
    } else {
      _dueDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    AccountsSnackBar.showError(context, msg);
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must have at least 2 characters';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
    if (!phoneRegExp.hasMatch(value.trim())) {
      return 'Phone must be 7-15 digits (optional +)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegExp.hasMatch(value.trim())) return 'Invalid email format';
    return null;
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final amount = double.tryParse(value.trim());
    if (amount == null) return 'Enter a valid number';
    if (amount < 0) return 'Amount cannot be negative';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      _showMessage('Please select a due date.');
      return;
    }

    setState(() => _saving = true);
    final store = AccountStoreProvider.of(context);
    try {
      final amount = double.tryParse(_amountCtrl.text.trim());
      if (amount == null) {
        _showMessage('Amount must be a valid number.');
        return;
      }
      final id = widget.account?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      // determine overdue, isPaid and status based on due date / payment state
      final now = DateTime.now();
      final isOverdue = _dueDate!.isBefore(now);
      final isNew = widget.account == null;

      // Rules:
      // - When creating a new account, never mark it as paid (isPaid = false).
      // - If an account is overdue it cannot be marked as paid (isPaid = false).
      // - For edits, preserve existing paid state unless the due date becomes overdue.
      final existingPaid = widget.account?.isPaid ?? false;
      final isPaid = isNew ? false : (existingPaid && !isOverdue);

      final status = isPaid ? 'Done' : (isOverdue ? 'Overdue' : 'Pending');

      final acc = Account(
        id: id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        amount: amount,
        dueDate: _dueDate!,
        // preserve existing lastContactDate when editing, otherwise set to now
        lastContactDate: widget.account?.lastContactDate ?? DateTime.now(),
        isPaid: isPaid,
        status: status,
      );

      // Persist locally and ensure remote sync completes before closing
      if (widget.account == null) {
        await store.addAccount(acc);
      } else {
        await store.updateAccount(acc);
      }

      // Ensure sync with remote and reload local store so UI sees latest data
      try {
        await store.sync();
      } catch (_) {
        // swallow sync errors but still attempt reload so local data is shown
      }
      await store.load();

      // close and signal success
      context.pop(true);
    } catch (e) {
      AccountsSnackBar.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildFormFields() {
    final colors = AppColors();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: _validateName,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Phone'),
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountCtrl,
          decoration: const InputDecoration(labelText: 'Amount'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _validateAmount,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Due Date'),
          subtitle: Text(_dueDate?.toLocal().toString().split(' ').first ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDate(context, _dueDate, (d) => setState(() => _dueDate = d)),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.Button),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(widget.account != null ? 'Update' : 'Add'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;
    final colors = AppColors();
    if (widget.asBottomSheet) {
      // compute sheet height before building widgets
      final screenHeight = MediaQuery.of(context).size.height;
      double sheetHeight;

      //Can change the buttomsheet height from here
      sheetHeight = screenHeight * 0.68;

      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: sheetHeight,
          width: double.infinity,
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // redesigned drag handle and header to match app vibe
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Row(
                      children: [
                        Column(

                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(isEdit ? 'Edit Creditor' : 'Add Creditor',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              isEdit ? 'Update Creditor details' : 'Create a new Creditor',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                        const Spacer(),
                        // colored close button that fits the app style
                        Container(
                          decoration: BoxDecoration(
                            color: colors.appbar_Color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            onPressed: () => context.pop(),
                            icon: Icon(Icons.close, color: colors.appbar_Color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Form(key: _formKey, child: _buildFormFields()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Creditor' : 'Add Creditor')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(key: _formKey, child: ListView(children: [_buildFormFields()])),
      ),
    );
  }
}

// New / updated: Account detail / Follow-Up Actions screen (redesigned)
class AccountFollowUpScreen extends StatefulWidget {
  final Account account;
  const AccountFollowUpScreen({super.key, required this.account});

  @override
  State<AccountFollowUpScreen> createState() => _AccountFollowUpScreenState();
}

class _AccountFollowUpScreenState extends State<AccountFollowUpScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _draftCtrl;
  int _selectedIndex = 0;
  bool _isEditing = false;
  DateTime? _scheduledDateTime;

  final List<String> _templates = [
    // Initial Contact
    '''Hi {name},

I’m reaching out regarding the outstanding balance of {amount} for {client}. Please let us know if there are any issues preventing payment or if you’d like to discuss a payment plan.

Best regards,''',
    // Follow-Up Reminder
    '''Hi {name},

Just a friendly reminder that the payment of {amount} for {client} is still outstanding. We’d appreciate your prompt attention to this matter.

Thank you,''',
    // Final Notice
    '''Hi {name},

This is a final notice regarding the outstanding balance of {amount} for {client}. The invoice is now overdue. Please contact us immediately to resolve this.

Regards,''',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _templates.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _draftCtrl = TextEditingController(text: _buildTemplateText(0));
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _draftCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedIndex = _tabController.index;
        if (!_isEditing) {
          _draftCtrl.text = _buildTemplateText(_selectedIndex);
        }
      });
    }
  }

  String _formatAmount(double v) => NumberFormat('#,##0.00').format(v);

  String _buildTemplateText(int idx) {
    final a = widget.account;
    final client = a.email.isNotEmpty ? a.email.split('@').first : (a.phone.isNotEmpty ? a.phone : a.name);
    final name = a.name;
    final amount = '\$${_formatAmount(a.amount)}';
    final daysOverdue = a.dueDate.isBefore(DateTime.now()) ? DateTime.now().difference(a.dueDate).inDays : 0;
    final overdueText = daysOverdue > 0 ? '$daysOverdue days overdue' : 'Due ${DateFormat.yMMMd().format(a.dueDate)}';
    return _templates[idx]
        .replaceAll('{name}', name)
        .replaceAll('{client}', client)
        .replaceAll('{amount}', amount)
        .replaceAll('{overdue}', overdueText);
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // on stop editing, if user cleared, refill default template for selected tab
        if (_draftCtrl.text.trim().isEmpty) _draftCtrl.text = _buildTemplateText(_selectedIndex);
      }
    });
  }

  void _copyDraft() {
    Clipboard.setData(ClipboardData(text: _draftCtrl.text));
    AccountsSnackBar.showSuccess(context, 'Message copied');
  }

  Future<void> _sendMessage() async {
    try {
      // placeholder integration
      await Future.delayed(const Duration(milliseconds: 600));
      AccountsSnackBar.showSuccess(context, 'Message sent');
    } catch (e) {
      AccountsSnackBar.showError(context, 'Send failed: $e');
    }
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null) return;
    setState(() {
      _scheduledDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
    AccountsSnackBar.showSuccess(context, 'Follow-up scheduled: ${DateFormat.yMMMd().add_jm().format(_scheduledDateTime!)}');
  }

  // helper: open phone dialer or show snackbar if unavailable
  Future<void> _launchPhone(String? phone) async {
    final p = phone?.trim() ?? '';
    if (p.isEmpty) {
      AccountsSnackBar.showError(context, 'No phone number available');
      return;
    }
    final uri = Uri(scheme: 'tel', path: p);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        AccountsSnackBar.showError(context, 'Cannot open dialer');
      }
    } catch (e) {
      AccountsSnackBar.showError(context, 'Failed to open dialer: $e');
    }
  }

  // helper: open mail client or show snackbar if unavailable
  Future<void> _launchEmail(String? email, [String? body]) async {
    final e = email?.trim() ?? '';

    if (e.isEmpty) {
      AccountsSnackBar.showError(context, 'No email address available');
      return;
    }

    final uri = Uri(
      scheme: 'mailto',
      path: e,
      query: Uri.encodeFull(
        'subject=Payment Reminder&body=${body ?? ''}',
      ),
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (err) {
      AccountsSnackBar.showError(context, 'Failed to open email app');
    }
  }

  Future<void> _openWhatsApp(String? phone, String message) async {
    String p = phone?.trim() ?? '';

    if (p.isEmpty) {
      AccountsSnackBar.showError(context, 'No phone number available');
      return;
    }

    // 🔥 Convert to international format (Pakistan example)
    if (p.startsWith('0')) {
      p = '92${p.substring(1)}';
    }

    p = p.replaceAll(RegExp(r'\D+'), '');

    final encodedMsg = Uri.encodeComponent(message);

    final uri = Uri.parse("https://wa.me/$p?text=$encodedMsg");

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AccountsSnackBar.showError(context, 'Failed to open WhatsApp');
    }
  }

  String _safeString(String? v) => (v == null || v.isEmpty) ? '-' : v;

  Widget _iconButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),

          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [


                CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 20)),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),

      ),
    );
  }

  // add helper to centralize mark-as-done logic
  Future<void> _confirmAndMarkDone(Account account) async {
    final store = AccountStoreProvider.of(context);
    final confirmed = await showDialog<bool>(
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
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 36),
              ),
              const SizedBox(height: 16),
              Text('Mark as Paid?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Do you want to mark\n"${account.name}" as paid?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
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
        final updated = account.copyWith(isPaid: true, status: 'Done');
        await store.updateAccount(updated);
        // attempt to sync so remote/local stay consistent
        try {
          await store.sync();
        } catch (_) {}
        await store.load();

        AccountsSnackBar.showSuccess(context, 'Marked as done');

        // schedule pop after frame to avoid navigator locked/dispose assertions
        SchedulerBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          // prefer Navigator pop if there is a local route to pop
          final nav = Navigator.maybeOf(context);
          if (nav != null && nav.canPop()) {
            nav.pop(true);
            return;
          }
          // fallback to GoRouter pop (defensive) - guard with mounted
          try {
            if (mounted) context.pop(true);
          } catch (_) {}
        });
      } catch (e) {
        AccountsSnackBar.showError(context, 'Failed to mark done: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final store = AccountStoreProvider.of(context);
    final name = a.name;
    final subtitle = a.email.isNotEmpty ? '${a.name} – ${a.email}' : '${a.name} – ${a.phone}';
    final amount = _formatAmount(a.amount);
    final now = DateTime.now();
    final overdue = a.dueDate.isBefore(now);
    final days = overdue ? now.difference(a.dueDate).inDays : a.dueDate.difference(now).inDays;
    final overdueLabel = overdue ? '$days days overdue' : 'Due in $days days';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creditor Detail'),
        automaticallyImplyLeading: true,
        actions: [
         PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black),
                  color: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
                  ),
                  onSelected: (v) async {
                    // defensive guards: do not perform edit/done if already paid
                    if (v == 'edit') {
                      if (a.isPaid) return;
                      final res = await context.pushNamed<bool>('addAccount', extra: {'asBottomSheet': true, 'account': a});
                      if (res == true && mounted) Navigator.of(context).pop(true);
                    } else if (v == 'done') {
                      if (a.isPaid) return;
                      await _confirmAndMarkDone(a);
                    } else if (v == 'delete') {
                       final confirmed = await showDialog<bool>(
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
                                Text('Are you sure you want to delete "${a.name}"? This action cannot be undone.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
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
                       if (confirmed == true) {
                         try {
                           await store.deleteAccount(a.id);
                           AccountsSnackBar.showSuccess(context, 'Account deleted');
                           if (mounted) Navigator.of(context).pop(true);
                         } catch (e) {
                           AccountsSnackBar.showError(context, 'Delete failed: $e');
                         }
                       }
                     }
                   },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[];
                    if (!a.isPaid) {
                      items.add(
                        PopupMenuItem(
                          value: 'done',
                          child: Row(children: [Icon(Icons.check, color: Colors.green.shade700), const SizedBox(width: 10), Text('Mark as Done', style: TextStyle(color: Colors.green.shade700))]),
                        ),
                      );
                      items.add(
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [Icon(Icons.edit, color: Colors.blueAccent), const SizedBox(width: 10), Text('Edit', style: TextStyle(color: Colors.blueAccent))]),
                        ),
                      );
                    }
                    items.add(
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [Icon(Icons.delete_outline, color: Colors.red.shade700), const SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.red.shade700))]),
                      ),
                    );
                    return items;
                  },
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            ListTile(title: const Text('Name'), subtitle: Text(a.name, style: Theme.of(context).textTheme.bodyLarge)),
                const Divider(),

            ListTile(
              title: const Text('Amount'),
              subtitle: Text('\$${_formatAmount(a.amount)}', style: Theme.of(context).textTheme.headlineSmall),
            ),
            const Divider(),
            ListTile(
              title: const Text('Due Date'),
              subtitle: Text(DateFormat.yMMMd().format(a.dueDate), style: Theme.of(context).textTheme.bodyLarge),
            ),
            const Divider(height: 32),
            ListTile(
              title: const Text('Status'),
              subtitle: Text(a.isPaid ? 'Paid' : 'Unpaid', style: TextStyle(color: a.isPaid ? Colors.green : Colors.red)),
            ),
            const Divider(height: 32),
            // Redesigned action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchPhone(a.phone),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchEmail(a.email, _draftCtrl.text),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Email'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

              ],
            ),
            const SizedBox(height: 18),
            // Next follow-up scheduling
            Text('Suggested next follow-up:', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(
              _scheduledDateTime != null
                  ? DateFormat.yMMMMd().add_jm().format(_scheduledDateTime!)
                  : '${DateFormat.yMMMMd().format(DateTime.now().add(const Duration(days: 1)))} at 10:00 AM',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Message templates (tabs)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.12)),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(width: 3.0, color: Colors.blue.shade700),
                      insets: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    labelColor: Colors.blue.shade700,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                    tabs: const [
                      Tab(text: 'Initial Contact'),
                      Tab(text: 'Follow-Up Reminder'),
                      Tab(text: 'Final Notice'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Message draft area with edit icon
            Row(
              children: [
                Expanded(child: Text('Message draft', style: Theme.of(context).textTheme.titleSmall)),
                IconButton(
                  tooltip: _isEditing ? 'Finish editing' : 'Edit draft',
                  icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded, color: Colors.grey.shade700),
                  onPressed: _toggleEdit,
                )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _draftCtrl,
              maxLines: 8,
              readOnly: !_isEditing,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _copyDraft,
                  icon: const Icon(Icons.copy, color: Colors.grey),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openWhatsApp(a.phone, _draftCtrl.text),
                    child: const Text('Send Message'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Contact information card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contact Information', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone, color: Colors.green),
                      title: Text(a.phone.isNotEmpty ? a.phone : '-'),
                      onTap: () => _launchPhone(a.phone),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined, color: Colors.blue),
                      title: Text(a.email.isNotEmpty ? a.email : '-'),
                      onTap: () => _launchEmail(a.email, _draftCtrl.text),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

