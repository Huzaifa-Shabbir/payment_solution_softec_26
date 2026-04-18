import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'account_model.dart';
import 'account_repository.dart';

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
  DateTime? _lastContact;
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
      _lastContact = a.lastContactDate;
    } else {
      _dueDate = DateTime.now();
      _lastContact = DateTime.now();
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
    if (_dueDate == null || _lastContact == null) {
      _showMessage('Please select both due date and last contact date.');
      return;
    }
    if (_dueDate!.isBefore(_lastContact!)) {
      _showMessage('Due date cannot be before last contact date.');
      return;
    }

    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtrl.text.trim());
      if (amount == null) {
        _showMessage('Amount must be a valid number.');
        return;
      }
      final id = widget.account?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final acc = Account(
        id: id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        amount: amount,
        dueDate: _dueDate!,
        // status will be computed by the app; new accounts start unpaid (isPaid=false)
        lastContactDate: _lastContact!,
        isPaid: widget.account?.isPaid ?? false,
      );
      if (widget.account == null) {
        await _repo.add(acc);
      } else {
        await _repo.update(acc);
      }
      // use go_router's pop
      context.pop(true);
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: _validateName,
        ),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Phone'),
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
        ),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ),
        TextFormField(
          controller: _amountCtrl,
          decoration: const InputDecoration(labelText: 'Amount'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _validateAmount,
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Due Date'),
          subtitle: Text(_dueDate?.toLocal().toString().split(' ').first ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDate(context, _dueDate, (d) => setState(() => _dueDate = d)),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Last Contact'),
          subtitle: Text(_lastContact?.toLocal().toString().split(' ').first ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDate(context, _lastContact, (d) => setState(() => _lastContact = d)),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Status will be computed automatically (Pending/Overdue). Use the dashboard to mark Done (paid).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
    if (widget.asBottomSheet) {
      // compute sheet height before building widgets
      final screenHeight = MediaQuery.of(context).size.height;
      double sheetHeight;

      //Can change the buttomsheet height from here
      sheetHeight = screenHeight * 0.67;

      return Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: sheetHeight,
          width: double.infinity,
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)), // larger rounded corners
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 6, // slightly reduced top whitespace
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // smaller drag handle (no top border line)
                    Container(
                      width: 36,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Row(
                      children: [
                        Text(
                          isEdit ? 'Edit Account' : 'Add Account',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Make the form scrollable inside the constrained box
                    Expanded(
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: _buildFormFields(),
                        ),
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
      appBar: AppBar(title: Text(isEdit ? 'Edit Account' : 'Add Account')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildFormFields(),
            ],
          ),
        ),
      ),
    );
  }
}
