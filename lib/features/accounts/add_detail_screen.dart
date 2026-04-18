import 'package:flutter/material.dart';
import 'account_model.dart';

class AccountDetailScreen extends StatelessWidget {
  final Account account;
  const AccountDetailScreen({super.key, required this.account});

  String _safeString(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;
  String _safeDate(DateTime? d) {
    if (d == null) return '—';
    try {
      return d.toLocal().toString().split(' ').first;
    } catch (_) {
      return d.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            ListTile(title: const Text('Name'), subtitle: Text(_safeString(account.name))),
            ListTile(title: const Text('Phone'), subtitle: Text(_safeString(account.phone))),
            ListTile(title: const Text('Email'), subtitle: Text(_safeString(account.email))),
            ListTile(title: const Text('Amount'), subtitle: Text(account.amount.toStringAsFixed(2))),
            ListTile(title: const Text('Due Date'), subtitle: Text(_safeDate(account.dueDate))),
            ListTile(title: const Text('Status'), subtitle: Text(_safeString(account.computedStatus))),
            ListTile(title: const Text('Last Contact'), subtitle: Text(_safeDate(account.lastContactDate))),
          ],
        ),
      ),
    );
  }
}
