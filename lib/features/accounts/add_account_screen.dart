import 'package:flutter/material.dart';
import 'account_model.dart';
import 'account_repository.dart';

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
      final id = widget.account?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final acc = Account(
        id: id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        amount: amount,
        dueDate: _dueDate ?? DateTime.now(),
        // status will be computed by the app; new accounts start unpaid (isPaid=false)
        lastContactDate: _lastContact ?? DateTime.now(),
        isPaid: widget.account?.isPaid ?? false,
      );
      if (widget.account == null) {
        await _repo.add(acc);
        _showMessage('Account added');
      } else {
        await _repo.update(acc);
        _showMessage('Account updated');
      }
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Account' : 'Add Account')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
              ),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  if (double.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                },
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
              // Status is determined by the app (isPaid + dueDate). User does not set it here.
              const SizedBox(height: 12),
              const Text(
                'Status will be computed automatically (Pending/Overdue). Use the dashboard to mark Done (paid).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : Text(isEdit ? 'Update' : 'Add'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
