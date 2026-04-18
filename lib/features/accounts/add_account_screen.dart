import 'package:flutter/material.dart';
import 'account_model.dart';
import 'account_repository.dart';
import 'accounts_snackbar.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? account;
  const AddAccountScreen({super.key, this.account});

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
  String _status = 'Pending';

  final AccountRepository _repo = AccountRepository();

  bool _saving = false;

  static final RegExp _phoneRegExp = RegExp(r'^\+?\d{7,15}$');
  static final RegExp _emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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
      _status = a.status;
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

  void _showError(String msg) {
    AccountsSnackBar.showError(context, msg);
  }

  void _showSuccess(String msg) {
    AccountsSnackBar.showSuccess(context, msg);
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must have at least 2 characters';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone is required';
    }

    String phone = value.trim().replaceAll(RegExp(r'\s+'), '');

    if (!_phoneRegExp.hasMatch(phone)) {
      return 'Phone must be 7–15 digits (optional +)';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegExp.hasMatch(value.trim())) return 'Invalid email format';
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
      _showError('Please select both due date and last contact date.');
      return;
    }

    if (_dueDate!.isBefore(_lastContact!)) {
      _showError('Due date cannot be before last contact date.');
      return;
    }

    setState(() => _saving = true);

    try {
      final amount = double.tryParse(_amountCtrl.text.trim());

      if (amount == null) {
        setState(() => _saving = false);
        _showError('Amount must be a valid number.');
        return;
      }

      final id = widget.account?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final acc = Account(
        id: id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        amount: amount,
        dueDate: _dueDate!,
        status: _status,
        lastContactDate: _lastContact!,
      );

      if (widget.account == null) {
        await _repo.add(acc);
        _showSuccess('Account added successfully');
      } else {
        await _repo.update(acc);
        _showSuccess('Account updated successfully');
      }

      if (mounted) Navigator.pop(context);
    } on AccountValidationException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(
      BuildContext context,
      DateTime? initial,
      ValueChanged<DateTime> onPicked,
      ) async {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Account' : 'Add Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
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
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                validator: _validateAmount,
              ),

              const SizedBox(height: 10),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due Date'),
                subtitle: Text(
                  _dueDate?.toLocal().toString().split(' ').first ?? '',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(
                    context,
                    _dueDate,
                        (d) => setState(() => _dueDate = d),
                  ),
                ),
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Last Contact'),
                subtitle: Text(
                  _lastContact?.toLocal().toString().split(' ').first ?? '',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(
                    context,
                    _lastContact,
                        (d) => setState(() => _lastContact = d),
                  ),
                ),
              ),

              DropdownButtonFormField<String>(
                value: _status,
                items: const ['Pending', 'Paid', 'Overdue']
                    .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
                decoration: const InputDecoration(labelText: 'Status'),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator()
                    : Text(isEdit ? 'Update' : 'Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}