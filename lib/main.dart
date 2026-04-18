import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'splash_Screen.dart';
import 'services/local_storage.dart';
import 'core/utils/app_messenger.dart';
import 'features/accounts/account_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  await LocalStorage.init();

  // one-time startup sync/reconcile
  try {
    print('[main] Running startup sync/reconcile with Supabase');
    await AccountRepository().printMergedUniqueCustomers();
    print('[main] Startup sync/reconcile completed');
  } catch (e) {
    print('[main] Startup sync/reconcile failed: $e');
  }

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment Solution Softec',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,

      home: const SplashScreen(),
    );
  }
}
