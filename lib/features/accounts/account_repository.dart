import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_model.dart';

class AccountRepository {
  final supabase = Supabase.instance.client;

  // CREATE
  Future<void> addAccount(Account account) async {
    await supabase.from('accounts').insert({
      'id': account.id,
      'name': account.name,
      'phone': account.phone,
      'email': account.email,
      'amount': account.amount,
      'due_date': account.dueDate.toIso8601String(),
      'status': account.status,
      'last_contact_date': account.lastContactDate.toIso8601String(),
    });
  }

  // READ
  Future<List<Account>> getAccounts() async {
    final response = await supabase.from('accounts').select();

    return (response as List)
        .map((e) => Account(
      id: e['id'],
      name: e['name'],
      phone: e['phone'],
      email: e['email'],
      amount: (e['amount'] as num).toDouble(),
      dueDate: DateTime.parse(e['due_date']),
      status: e['status'],
      lastContactDate: DateTime.parse(e['last_contact_date']),
    ))
        .toList();
  }

  // UPDATE
  Future<void> updateAccount(Account account) async {
    await supabase
        .from('accounts')
        .update({
      'name': account.name,
      'phone': account.phone,
      'email': account.email,
      'amount': account.amount,
      'due_date': account.dueDate.toIso8601String(),
      'status': account.status,
      'last_contact_date':
      account.lastContactDate.toIso8601String(),
    })
        .eq('id', account.id);
  }

  // DELETE
  Future<void> deleteAccount(String id) async {
    await supabase.from('accounts').delete().eq('id', id);
  }
}