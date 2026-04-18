import 'dart:convert';
import 'account_model.dart';
import '../../services/local_storage.dart' as LocalStorage;
import 'package:supabase_flutter/supabase_flutter.dart';
// rename local service alias to avoid shadowing package symbol
import '../../services/supabase_service.dart' as SupabaseService;

class AccountRepository {
  static const String _key = 'accounts';

  String _humanizeError(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length)
        : raw;
  }

  Future<List<Account>> getAll() async {
    try {
      final raw = LocalStorage.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final accounts = <Account>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        try {
          accounts.add(Account.fromJson(item));
        } on AccountValidationException {
          // Skip malformed records so one bad entry does not block the whole list.
          continue;
        }
      }
      return accounts;
    } catch (e) {
      throw Exception('Failed to load accounts: ${_humanizeError(e)}');
    }
  }

  Future<void> saveAll(List<Account> accounts) async {
    try {
      final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await LocalStorage.setString(_key, encoded);
    } catch (e) {
      throw Exception('Failed to save accounts: ${_humanizeError(e)}');
    }
  }

  Future<Account> add(Account account) async {
    try {
      final list = await getAll();
      final exists = list.any((a) => a.id == account.id);
      if (exists) {
        throw Exception('Account already exists.');
      }
      list.add(account);
      await saveAll(list);
      return account;
    } on AccountValidationException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to add account: ${_humanizeError(e)}');
    }
  }

  Future<void> update(Account account) async {
    try {
      final list = await getAll();
      final idx = list.indexWhere((a) => a.id == account.id);
      if (idx == -1) throw Exception('Account not found');
      list[idx] = account;
      await saveAll(list);

      // attempt remote update/insert
      try {
        final payload = _toSupabasePayloadFromAccount(account);
        print('[AccountRepository] Remote update: trying update by id=${account.id} payload=$payload');

        // Try updating by id first
        var res = await Supabase.instance.client
            .from('customers')
            .update(payload)
            .eq('id', account.id)
            .select();
        var rows = _normalizeResponseToList(res);

        if (rows.isNotEmpty) {
          print('[AccountRepository] Remote update succeeded for id=${account.id} row=${rows.first}');
          return;
        }

        // If no rows affected by id, try to find remote by email
        String? foundId;
        if (account.email.isNotEmpty) {
          try {
            final byEmail = await Supabase.instance.client.from('customers').select().eq('email', account.email).limit(1);
            final candidates = _normalizeResponseToList(byEmail);
            if (candidates.isNotEmpty) foundId = _safeString(candidates.first['id']);
            if (foundId != null && foundId.isNotEmpty) {
              print('[AccountRepository] Remote record found by email=${account.email} -> id=$foundId');
            }
          } catch (e) {
            print('[AccountRepository] Remote lookup by email failed: $e');
          }
        }

        // If not found by email, try phone
        if ((foundId == null || foundId.isEmpty) && account.phone.isNotEmpty) {
          try {
            final byPhone = await Supabase.instance.client.from('customers').select().eq('phone', account.phone).limit(1);
            final candidates = _normalizeResponseToList(byPhone);
            if (candidates.isNotEmpty) foundId = _safeString(candidates.first['id']);
            if (foundId != null && foundId.isNotEmpty) {
              print('[AccountRepository] Remote record found by phone=${account.phone} -> id=$foundId');
            }
          } catch (e) {
            print('[AccountRepository] Remote lookup by phone failed: $e');
          }
        }

        if (foundId != null && foundId.isNotEmpty) {
          try {
            final r2 = await Supabase.instance.client.from('customers').update(payload).eq('id', foundId).select();
            final r2rows = _normalizeResponseToList(r2);
            if (r2rows.isNotEmpty) {
              print('[AccountRepository] Remote update succeeded for foundId=$foundId row=${r2rows.first}');
            } else {
              print('[AccountRepository] Remote update by foundId returned no rows; attempting insert');
              final ins = await Supabase.instance.client.from('customers').insert(payload).select();
              final insRows = _normalizeResponseToList(ins);
              print('[AccountRepository] Remote insert after failed update returned: ${insRows.isNotEmpty ? insRows.first : ins}');
            }
          } catch (e) {
            print('[AccountRepository] Remote update by foundId failed: $e');
          }
        } else {
          // no remote match -> insert
          try {
            print('[AccountRepository] Remote insert: no matching remote record, inserting payload');
            final ins = await Supabase.instance.client.from('customers').insert(payload).select();
            final insRows = _normalizeResponseToList(ins);
            if (insRows.isNotEmpty) {
              print('[AccountRepository] Remote insert succeeded: ${insRows.first}');
            } else {
              print('[AccountRepository] Remote insert returned no rows: $ins');
            }
          } catch (e) {
            print('[AccountRepository] Remote insert failed: $e');
          }
        }
      } catch (e, st) {
        print('[AccountRepository] Remote update/insert attempt failed: $e');
        print(st);
      }
    } on AccountValidationException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update account: ${_humanizeError(e)}');
    }
  }

  Future<void> delete(String id) async {
    try {
      if (id.trim().isEmpty) {
        throw Exception('Account id is required.');
      }

      final list = await getAll();
      Account? acct;

      try {
        acct = list.firstWhere((a) => a.id == id);
      } catch (e) {
        acct = null;
      }
      final newList = list.where((a) => a.id != id).toList();
      await saveAll(newList);

      // attempt remote delete
      try {
        print('[AccountRepository] Remote delete: trying delete by id=$id');
        var res = await Supabase.instance.client.from('customers').delete().eq('id', id).select();
        var rows = _normalizeResponseToList(res);
        if (rows.isNotEmpty) {
          print('[AccountRepository] Remote delete succeeded for id=$id row=${rows.first}');
          return;
        }

        // if not deleted by id, try to find by email/phone from local account before it was removed
        String? foundId;
        if (acct != null && acct.email.isNotEmpty) {
          try {
            final byEmail = await Supabase.instance.client.from('customers').select().eq('email', acct.email).limit(1);
            final candidates = _normalizeResponseToList(byEmail);
            if (candidates.isNotEmpty) foundId = _safeString(candidates.first['id']);
            if (foundId != null && foundId.isNotEmpty) {
              print('[AccountRepository] Remote record found by email=${acct.email} -> id=$foundId');
            }
          } catch (e) {
            print('[AccountRepository] Remote lookup by email failed during delete: $e');
          }
        }

        if ((foundId == null || foundId.isEmpty) && acct != null && acct.phone.isNotEmpty) {
          try {
            final byPhone = await Supabase.instance.client.from('customers').select().eq('phone', acct.phone).limit(1);
            final candidates = _normalizeResponseToList(byPhone);
            if (candidates.isNotEmpty) foundId = _safeString(candidates.first['id']);
            if (foundId != null && foundId.isNotEmpty) {
              print('[AccountRepository] Remote record found by phone=${acct.phone} -> id=$foundId');
            }
          } catch (e) {
            print('[AccountRepository] Remote lookup by phone failed during delete: $e');
          }
        }

        if (foundId != null && foundId.isNotEmpty) {
          try {
            final r2 = await Supabase.instance.client.from('customers').delete().eq('id', foundId).select();
            final r2rows = _normalizeResponseToList(r2);
            if (r2rows.isNotEmpty) {
              print('[AccountRepository] Remote delete succeeded for foundId=$foundId row=${r2rows.first}');
            } else {
              print('[AccountRepository] Remote delete by foundId returned no rows (response=$r2)');
            }
          } catch (e) {
            print('[AccountRepository] Remote delete by foundId failed: $e');
          }
        } else {
          print('[AccountRepository] No remote match found to delete for local id=$id');
        }
      } catch (e, st) {
        print('[AccountRepository] Remote delete attempt failed: $e');
        print(st);
      }
    } catch (e) {
      throw Exception('Failed to delete account: ${_humanizeError(e)}');
    }
  }

  // Helpers to safely parse remote values
  double _parseRemoteDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  DateTime? _parseRemoteDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      return DateTime.tryParse(v);
    }
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return null;
  }

  String _safeString(dynamic v) => v == null ? '' : v.toString();

  // Compute a non-null status from a remote row (fallbacks to Pending/Overdue based on due date)
  String _computeStatusFromRemoteRow(Map<String, dynamic> row) {
    final raw = _safeString(row['status']);
    if (raw.isNotEmpty) return raw;
    // try to infer from due_Date or dueDate
    final due = _parseRemoteDate(row['due_Date'] ?? row['dueDate']);
    if (due != null) {
      final now = DateTime.now();
      if (due.isBefore(now)) return 'Overdue';
      return 'Pending';
    }
    return 'Pending';
  }

  // Normalize various Supabase response shapes into a List<Map<String, dynamic>>
  List<Map<String, dynamic>> _normalizeResponseToList(dynamic res) {
    try {
      if (res is List) {
        return res.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          // if item is primitive or unexpected, represent as empty map to avoid crashes
          return <String, dynamic>{};
        }).toList();
      }

      if (res is Map) {
        // Some clients return { 'data': [...] } or similar wrappers
        if (res['data'] is List) {
          final raw = res['data'] as List;
          return raw.map<Map<String, dynamic>>((e) {
            if (e is Map<String, dynamic>) return e;

            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }).toList();
        }

        // If the map itself looks like a single row, wrap it
        return [res.map((k, v) => MapEntry(k.toString(), v))];
      }
    } catch (e) {
      print('[AccountRepository] _normalizeResponseToList failed: $e');
    }
    return <Map<String, dynamic>>[];
  }

  // Build a Supabase-safe payload from a local Account.
  // Maps our fields to the customers table columns
  Map<String, dynamic> _toSupabasePayloadFromAccount(Account acct) {
    final payload = <String, dynamic>{
      // DO NOT include 'id' here — Supabase manages the primary key.
      'name': acct.name,
      'email': acct.email,
      'phone': acct.phone,
      'last_Follow_Up_Date': acct.lastContactDate.toIso8601String().split('T').first,
      'amount': acct.amount,
      'due_Date': acct.dueDate.toIso8601String().split('T').first,
      // ensure status is never null/empty: prefer explicit status, otherwise computedStatus
      'status': acct.status.isNotEmpty ? acct.status : acct.computedStatus,
    };

    payload.removeWhere((k, v) => v == null || (v is String && v.isEmpty));
    return payload;
  }
  // Fetch all rows from Supabase 'customers' table.
  Future<List<Map<String, dynamic>>> fetchRemoteCustomers() async {
    try {
      final res = await Supabase.instance.client.from('customers').select();
      print('[AccountRepository] fetchRemoteCustomers: raw response type=${res.runtimeType}');

      final list = _normalizeResponseToList(res);
      print('[AccountRepository] fetchRemoteCustomers: normalized to ${list.length} rows (showing up to 10):');
      for (var i = 0; i < list.length && i < 10; i++) {
        print('[AccountRepository] row[$i] = ${list[i]}');
      }
      return list;
    } catch (e) {
      print('[AccountRepository] fetchRemoteCustomers failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  // Compare remote rows with local accounts and print differences.
  // Matching: try email (case-insensitive), then phone.
  Future<void> compareWithRemoteAndPrintDifferences() async {
    try {
      final local = await getAll();
      final remoteRows = await fetchRemoteCustomers();
      print('[AccountRepository] compareWithRemote: local=${local.length} remote=${remoteRows.length}');

      // build quick lookup maps
      final localByEmail = <String, Account>{};
      final localByPhone = <String, Account>{};
      for (final l in local) {
        final e = l.email.trim().toLowerCase();
        final p = l.phone.trim();
        if (e.isNotEmpty) localByEmail[e] = l;
        if (p.isNotEmpty) localByPhone[p] = l;
      }

      final matchedLocalIds = <String>{};
      final differences = <String>[];
      final remoteOnly = <Map<String, dynamic>>[];

      for (final row in remoteRows) {
        final rName = _safeString(row['name']);
        final rEmail = _safeString(row['email']).toLowerCase();
        final rPhone = _safeString(row['phone']);
        final rAmount = _parseRemoteDouble(row['amount']);
        final rDue = _parseRemoteDate(row['due_Date'] ?? row['dueDate']);
        final rLast = _parseRemoteDate(row['last_Follow_Up_Date'] ?? row['lastContactDate']);
        final rStatus = _safeString(row['status']);
        // find local match
        Account? match;
        if (rEmail.isNotEmpty && localByEmail.containsKey(rEmail)) {
          match = localByEmail[rEmail];
        } else if (rPhone.isNotEmpty && localByPhone.containsKey(rPhone)) {
          match = localByPhone[rPhone];
        }

        if (match == null) {
          remoteOnly.add(row);
          print('[AccountRepository] REMOTE-ONLY id=${row['id']} name="$rName" email="$rEmail" phone="$rPhone"');
          continue;
        }

        matchedLocalIds.add(match.id);

        // compare fields and collect diffs
        final diffs = <String>[];
        if (match.name.trim() != rName.trim()) {
          diffs.add('name: local="${match.name}" remote="$rName"');
        }
        if (match.email.trim().toLowerCase() != rEmail.trim()) {
          diffs.add('email: local="${match.email}" remote="$rEmail"');
        }
        if (match.phone.trim() != rPhone.trim()) {
          diffs.add('phone: local="${match.phone}" remote="$rPhone"');
        }
        if ((match.amount - rAmount).abs() > 0.0001) {
          diffs.add('amount: local=${match.amount} remote=$rAmount');
        }
        final localDue = match.dueDate;
        if ((rDue != null && !rDue.isAtSameMomentAs(localDue)) && (rDue != null || localDue != null)) {
          diffs.add('dueDate: local=${localDue.toIso8601String()} remote=${rDue?.toIso8601String() ?? 'null'}');
        }
        final localLast = match.lastContactDate;
        if ((rLast != null && !rLast.isAtSameMomentAs(localLast)) && (rLast != null || localLast != null)) {
          diffs.add('lastContactDate: local=${localLast.toIso8601String()} remote=${rLast?.toIso8601String() ?? 'null'}');
        }
        if (match.status.trim() != rStatus.trim()) {
          diffs.add('status: local="${match.status}" remote="$rStatus"');
        }

        print('[AccountRepository] comparing remote id=${row['id']} email=${row['email']} phone=${row['phone']} with local match=${match?.id ?? 'none'}');

        if (diffs.isNotEmpty) {
          final msg = '[AccountRepository] DIFF localId=${match.id} remoteId=${row['id']} -> ${diffs.join('; ')}';
          differences.add(msg);
          print(msg);
        } else {
          print('[AccountRepository] MATCH localId=${match.id} remoteId=${row['id']} (no differences)');
        }
      }

      // local-only (not matched to any remote)
      final localOnly = local.where((l) => !matchedLocalIds.contains(l.id)).toList();
      for (final l in localOnly) {
        print('[AccountRepository] LOCAL-ONLY id=${l.id} name="${l.name}" email="${l.email}" phone="${l.phone}"');
      }

      print('[AccountRepository] Comparison complete. diffs=${differences.length} remoteOnly=${remoteOnly.length} localOnly=${localOnly.length}');
    } catch (e) {
      print('[AccountRepository] compareWithRemoteAndPrintDifferences failed: $e');
    }
  }

  // Print all local accounts and remote Supabase 'customers' rows to console for debugging.
  Future<void> printAllLocalAndRemote() async {
    try {
      final local = await getAll();
      print('[AccountRepository] ---------- LOCAL ACCOUNTS (${local.length}) ----------');
      for (var i = 0; i < local.length; i++) {
        try {
          print('[AccountRepository] LOCAL[$i]: ${local[i].toJson()}');
        } catch (e) {
          print('[AccountRepository] LOCAL[$i] print failed: $e');
        }
      }

      final remote = await fetchRemoteCustomers();
      print('[AccountRepository] ---------- REMOTE SUPABASE customers (${remote.length}) ----------');
      for (var i = 0; i < remote.length; i++) {
        try {
          print('[AccountRepository] REMOTE[$i]: ${remote[i]}');
        } catch (e) {
          print('[AccountRepository] REMOTE[$i] print failed: $e');
        }
      }

      print('[AccountRepository] ---------- PRINT COMPLETE ----------');
    } catch (e) {
      print('[AccountRepository] printAllLocalAndRemote failed: $e');
      rethrow;
    }
  }

  // Print merged unique customers (merge remote + local by remote id, email, phone).
  // For local-only customers, insert them into Supabase and print responses/errors.
  Future<void> printMergedUniqueCustomers() async {
    try {
      final local = await getAll();
      final remoteRows = await fetchRemoteCustomers();
      print('[AccountRepository] printMergedUniqueCustomers: local=${local.length} remote=${remoteRows.length}');

      // Build remote lookup maps
      final Map<String, Map<String, dynamic>> remoteById = {};
      final Map<String, String> remoteIdByEmail = {};
      final Map<String, String> remoteIdByPhone = {};

      for (final row in remoteRows) {
        final rid = _safeString(row['id']);
        if (rid.isEmpty) continue;
        remoteById[rid] = row;
        final email = _safeString(row['email']).toLowerCase();
        final phone = _safeString(row['phone']);
        if (email.isNotEmpty) remoteIdByEmail[email] = rid;
        if (phone.isNotEmpty) remoteIdByPhone[phone] = rid;
      }

      // merged keyed by canonical id (remote id preferred, else local id)
      final Map<String, Map<String, dynamic>> merged = {};
      final List<Account> localOnlyAccounts = [];

      // Start with remote rows as base (canonical id = remote id)
      for (final entry in remoteById.entries) {
        final canonicalId = entry.key;
        final row = entry.value;
        final resolvedStatus = _computeStatusFromRemoteRow(row);
        print('[AccountRepository] resolved remote status for id=$canonicalId -> $resolvedStatus');
        merged[canonicalId] = {
          'id': canonicalId,
          'name': _safeString(row['name']),
          'email': _safeString(row['email']),
          'phone': _safeString(row['phone']),
          'amount': _parseRemoteDouble(row['amount']),
          'dueDate': _parseRemoteDate(row['due_Date'] ?? row['dueDate'])?.toIso8601String(),
          'lastContactDate': _parseRemoteDate(row['last_Follow_Up_Date'] ?? row['lastContactDate'])?.toIso8601String(),
          'status': resolvedStatus,
          'source': 'remote',
        };
      }

      // Merge local accounts (prefer local values). Track local-only accounts for insertion.
      for (final acct in local) {
        final localEmail = acct.email.trim().toLowerCase();
        final localPhone = acct.phone.trim();

        String? matchedRemoteId;
        if (localEmail.isNotEmpty && remoteIdByEmail.containsKey(localEmail)) {
          matchedRemoteId = remoteIdByEmail[localEmail];
        } else if (localPhone.isNotEmpty && remoteIdByPhone.containsKey(localPhone)) {
          matchedRemoteId = remoteIdByPhone[localPhone];
        }

        final localPreferredStatus = acct.status.isNotEmpty ? acct.status : acct.computedStatus;

        if (matchedRemoteId != null && merged.containsKey(matchedRemoteId)) {
          final m = merged[matchedRemoteId]!;
          // prefer local non-empty values / local numeric values
          if (acct.name.isNotEmpty) m['name'] = acct.name;
          if (acct.email.isNotEmpty) m['email'] = acct.email;
          if (acct.phone.isNotEmpty) m['phone'] = acct.phone;
          m['amount'] = acct.amount;
          m['dueDate'] = acct.dueDate.toIso8601String();
          m['lastContactDate'] = acct.lastContactDate.toIso8601String();
          m['status'] = localPreferredStatus;
          m['source'] = 'merged';
          print('[AccountRepository] merged local into remote id=$matchedRemoteId status-> ${m['status']}');
        } else {
          // No remote match -> create merged entry keyed by local id (canonical id = local id)
          final canonicalId = acct.id;
          if (!merged.containsKey(canonicalId)) {
            merged[canonicalId] = {
              'id': canonicalId,
              'name': acct.name,
              'email': acct.email,
              'phone': acct.phone,
              'amount': acct.amount,
              'dueDate': acct.dueDate.toIso8601String(),
              'lastContactDate': acct.lastContactDate.toIso8601String(),
              'status': localPreferredStatus,
              'source': 'local',
            };
            localOnlyAccounts.add(acct); // mark for insertion
            print('[AccountRepository] local-only account marked for insert localId=$canonicalId status-> $localPreferredStatus');
          } else {
            // If collision (unlikely), merge prefer local values
            final m = merged[canonicalId]!;
            if (acct.name.isNotEmpty) m['name'] = acct.name;
            if (acct.email.isNotEmpty) m['email'] = acct.email;
            if (acct.phone.isNotEmpty) m['phone'] = acct.phone;
            m['amount'] = acct.amount;
            m['dueDate'] = acct.dueDate.toIso8601String();
            m['lastContactDate'] = acct.lastContactDate.toIso8601String();
            m['status'] = localPreferredStatus;
            m['source'] = 'merged';
          }
        }
      }

      // Attempt to insert local-only accounts into Supabase, print payloads/responses/errors.
      for (final acct in localOnlyAccounts) {
        try {
          final payload = _toSupabasePayloadFromAccount(acct);
          print('[AccountRepository] Inserting local-only account to Supabase localId=${acct.id} payload=$payload');
          final res = await Supabase.instance.client.from('customers').insert(payload).select();
          final normalized = _normalizeResponseToList(res);
          if (normalized.isNotEmpty) {
            final returnedRow = normalized.first;
            final returnedId = _safeString(returnedRow['id']);
            print('[AccountRepository] Insert succeeded localId=${acct.id} returned remote id=$returnedId row=$returnedRow');
            // If insertion returned remote id, update merged key: remove old (local) and add new keyed by remote id.
            final oldKey = acct.id;
            final newKey = returnedId.isNotEmpty ? returnedId : oldKey;
            final mergedEntry = merged.remove(oldKey);
            final updatedEntry = {
              'id': newKey,
              'name': acct.name,
              'email': acct.email,
              'phone': acct.phone,
              'amount': acct.amount,
              'dueDate': acct.dueDate.toIso8601String(),
              'lastContactDate': acct.lastContactDate.toIso8601String(),
              'status': acct.status.isNotEmpty ? acct.status : acct.computedStatus,
              'source': 'inserted',
              'remoteRow': returnedRow,
            };
            merged[newKey] = updatedEntry;
            print('[AccountRepository] merged key updated: old=$oldKey new=$newKey status=${updatedEntry['status']}');
          } else {
            print('[AccountRepository] Insert returned no rows for localId=${acct.id}, response=$res');
          }
        } catch (e, st) {
          print('[AccountRepository] FAILED to insert localId=${acct.id} error=$e');
          print(st);
        }
      }

      // Reconcile merged entries into local storage: create/update local accounts so local reflects merged data.
      try {
        final List<Account> newLocalList = [];
        // build helper lookups from existing local before changes
        final localById = { for (var a in local) a.id: a };
        final localByEmail = { for (var a in local.where((e) => e.email.isNotEmpty)) a.email.trim().toLowerCase(): a };
        final localByPhone = { for (var a in local.where((e) => e.phone.isNotEmpty)) a.phone.trim(): a };

        for (final entry in merged.values) {
          final canonicalId = '${entry['id'] ?? ''}';
          final name = '${entry['name'] ?? ''}';
          final email = '${entry['email'] ?? ''}';
          final phone = '${entry['phone'] ?? ''}';
          final amount = (entry['amount'] is num) ? (entry['amount'] as num).toDouble() : double.tryParse('${entry['amount'] ?? '0'}') ?? 0.0;
          DateTime dueDate = DateTime.now();
          DateTime lastContact = DateTime.now();
          try {
            if (entry['dueDate'] != null) dueDate = DateTime.parse(entry['dueDate']);
          } catch (_) {}
          try {
            if (entry['lastContactDate'] != null) lastContact = DateTime.parse(entry['lastContactDate']);
          } catch (_) {}
          final status = '${entry['status'] ?? ''}';
          final source = '${entry['source'] ?? 'merged'}';


          Account? existing;
          if (localById.containsKey(canonicalId)) {
            existing = localById[canonicalId];
          } else if (email.isNotEmpty && localByEmail.containsKey(email.toLowerCase())) {
            existing = localByEmail[email.toLowerCase()];
          } else if (phone.isNotEmpty && localByPhone.containsKey(phone)) {
            existing = localByPhone[phone];
          }

          try {
            if (existing != null) {
              // recreate account with canonicalId (so we have one id per user) and merged fields
              final updated = Account(
                id: canonicalId.isNotEmpty ? canonicalId : existing.id,
                name: name.isNotEmpty ? name : existing.name,
                phone: phone.isNotEmpty ? phone : existing.phone,
                email: email.isNotEmpty ? email : existing.email,
                amount: amount,
                dueDate: dueDate,
                status: status.isNotEmpty ? status : existing.status,
                lastContactDate: lastContact,
                isPaid: existing.isPaid || (status.toLowerCase() == 'paid' || status.toLowerCase() == 'done'),
              );
              newLocalList.add(updated);
              print('[AccountRepository] LOCAL UPDATE: id=${updated.id} source=$source name=${updated.name}');
            } else {
              // create new local account for remote-only entries
              final created = Account(
                id: canonicalId.isNotEmpty ? canonicalId : DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                phone: phone,
                email: email,
                amount: amount,
                dueDate: dueDate,
                status: status,
                lastContactDate: lastContact,
                isPaid: (status.toLowerCase() == 'paid' || status.toLowerCase() == 'done'),
              );
              newLocalList.add(created);
              print('[AccountRepository] LOCAL CREATE: id=${created.id} source=$source name=${created.name}');
            }
          } catch (e, st) {
            print('[AccountRepository] Failed to create/update local account for merged id=$canonicalId error=$e');
            print(st);
            // skip this entry
          }
        }

        // Save updated local list (deduplicated by id)
        final deduped = <String, Account>{};
        for (final a in newLocalList) {
          deduped[a.id] = a;
        }
        final finalList = deduped.values.toList();
        await saveAll(finalList);
        print('[AccountRepository] Local storage reconciled and saved ${finalList.length} accounts');
      } catch (e, st) {
        print('[AccountRepository] Failed to reconcile local storage: $e');
        print(st);
      }

      // Print merged unique customers (single canonical id per entry)
      final keys = merged.keys.toList();
      print('[AccountRepository] ---------- MERGED UNIQUE CUSTOMERS (${keys.length}) ----------');
      for (var i = 0; i < keys.length; i++) {
        final k = keys[i];
        final entry = merged[k]!;
        print('[AccountRepository] MERGED[$i]: $entry');
      }
      print('[AccountRepository] ---------- MERGE COMPLETE ----------');
    } catch (e) {
      print('[AccountRepository] printMergedUniqueCustomers failed: $e');
    }
  }
}
