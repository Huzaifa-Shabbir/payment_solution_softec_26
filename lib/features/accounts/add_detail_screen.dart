import 'package:flutter/material.dart';
import 'account_model.dart';

class AccountDetailScreen extends StatelessWidget {
  final Account account;
  const AccountDetailScreen({super.key, required this.account});

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
            ListTile(title: const Text('Name'), subtitle: Text(account.name)),
            ListTile(title: const Text('Phone'), subtitle: Text(account.phone)),
            ListTile(title: const Text('Email'), subtitle: Text(account.email)),
            ListTile(title: const Text('Amount'), subtitle: Text(account.amount.toStringAsFixed(2))),
            ListTile(title: const Text('Due Date'), subtitle: Text(account.dueDate.toLocal().toString().split(' ').first)),
            ListTile(title: const Text('Status'), subtitle: Text(account.status)),
            ListTile(title: const Text('Last Contact'), subtitle: Text(account.lastContactDate.toLocal().toString().split(' ').first)),
          ],
        ),
      ),
    );
  }
}

