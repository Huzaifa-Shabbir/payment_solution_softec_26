import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_model.dart';

class AccountRepository {
  final SupabaseClient supabase = Supabase.instance.client;

  // -------------------------
  // Helper: Map Supabase row → Account
  // -------------------------
  Account _fromMap(Map<String, dynamic> data) {
    return Account(
      id: data['id'],
      name: data['name'],
      phone: data['phone'],
      email: data['email'],
      amount: (data['amount'] as num).toDouble(),
      dueDate: DateTime.parse(data['due_date']),
      status: data['status'],
      lastContactDate: DateTime.parse(data['last_contact_date']),
    );
  }

  // -------------------------
  // CREATE
  // -------------------------
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

  // -------------------------
  // READ ALL
  // -------------------------
  Future<List<Account>> getAllAccounts() async {
    final List<dynamic> data =
    await supabase.from('accounts').select();

    return data
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------
  // READ BY ID
  // -------------------------
  Future<Account?> getAccountById(String id) async {
    final data = await supabase
        .from('accounts')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;

    return _fromMap(data);
  }

  // -------------------------
  // UPDATE
  // -------------------------
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
      'last_contact_date': account.lastContactDate.toIso8601String(),
    })
        .eq('id', account.id);
  }

  // -------------------------
  // DELETE
  // -------------------------
  Future<void> deleteAccount(String id) async {
    await supabase
        .from('accounts')
        .delete()
        .eq('id', id);
  }
}