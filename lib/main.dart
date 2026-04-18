import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/supabase_service.dart';
import 'splash_Screen.dart';
import 'services/local_storage.dart';
import 'core/utils/app_messenger.dart';
import 'features/accounts/account_repository.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/accounts/account_list_screen.dart';
import 'features/accounts/add_account_screen.dart';
import 'features/accounts/add_detail_screen.dart';
import 'features/accounts/account_model.dart';
import 'features/core/Theme.dart';
import 'features/setting/setting.dart';
import 'core/utils/state_Management.dart';

// single app-wide store instance (initialized in main before runApp)
final AccountStore accountStore = AccountStore();

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

  // load initial account data before showing UI
  await accountStore.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          name: 'splash',
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          name: 'dashboard',
          path: '/dashboard',
          builder: (context, state) => const Dashboard(),
        ),
        GoRoute(
          name: 'accounts',
          path: '/accounts',
          builder: (context, state) => const AccountListScreen(),
        ),
        GoRoute(
          name: 'accountDetail',
          path: '/accounts/detail',
          builder: (context, state) {
            final extra = state.extra;
            return AccountDetailScreen(account: extra as dynamic);
          },
        ),
        GoRoute(
          name: 'addAccount',
          path: '/add',
          pageBuilder: (context, state) {
            final extra = state.extra;
            Account? account;
            bool asBottom = false;
            if (extra is Map) {
              account = extra['account'] as Account?;
              asBottom = extra['asBottomSheet'] == true;
            } else if (extra is Account) {
              account = extra;
            }
            return CustomTransitionPage(
              key: state.pageKey,
              opaque: false,
<<<<<<< Updated upstream
              barrierColor: Colors.black.withOpacity(0.15),
=======
              barrierColor: Colors.black.withValues(alpha: 0.15),
>>>>>>> Stashed changes
              barrierDismissible: true,
              maintainState: true,
              child: AddAccountScreen(account: account, asBottomSheet: asBottom),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOut));
                return SlideTransition(position: animation.drive(tween), child: child);
              },
            );
          },
        ),
        GoRoute(
          name: 'settings',
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

    // Listen to ThemeController for theme changes across the app.
    return AccountStoreProvider(
      store: accountStore,
      child: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'Payment Solution Softec',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: appScaffoldMessengerKey,
            routerConfig: router,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeController.instance.themeMode,
          );
        },
      ),
    );
  }
}
