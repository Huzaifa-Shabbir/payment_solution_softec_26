import 'account_repository.dart';
import 'account_model.dart';

/// Fallback helpers for AccountRepository used by UI code.
/// These are no-op implementations to satisfy existing callers (compile + runtime).
/// Replace with real local storage / sync logic as needed.
extension AccountRepositoryHelpers on AccountRepository {
  /// Best-effort local upsert. Currently a no-op — add LocalStorage interaction here.
  Future<void> upsertLocal(Account acc) async {
    // Example: integrate with your LocalStorage service here.
    // try { await LocalStorage.putAccount(acc); } catch (_) {}
    // For now keep as noop to avoid breaking builds.
    // Debug log:
    // ignore: avoid_print
    print('[AccountRepositoryHelpers] upsertLocal called for id=${acc.id}');
  }

  /// Best-effort local delete. Currently a no-op — add LocalStorage interaction here.
  Future<void> deleteLocal(String id) async {
    // Example: integrate with your LocalStorage service here.
    // try { await LocalStorage.removeAccount(id); } catch (_) {}
    // For now keep as noop.
    // ignore: avoid_print
    print('[AccountRepositoryHelpers] deleteLocal called for id=$id');
  }

  /// Best-effort sync from Supabase to local storage. Currently a no-op placeholder.
  Future<void> syncFromSupabase() async {
    // Implement actual sync logic here if you have Supabase/local APIs available.
    // ignore: avoid_print
    print('[AccountRepositoryHelpers] syncFromSupabase called (noop)');
  }
}

