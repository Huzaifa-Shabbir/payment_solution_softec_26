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
import 'features/accounts/account_model.dart';
import 'features/core/Theme.dart';
import 'features/setting/setting.dart';
import 'core/utils/state_Management.dart';
import 'features/reports/analytics_screen.dart';

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
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            // map location -> selected index for icon coloring
            int _locToIndex(String loc) {
              if (loc.startsWith('/accounts')) return 1;
              if (loc.startsWith('/analytics')) return 2;
              if (loc.startsWith('/settings')) return 3;
              return 0; // dashboard and default
            }

            final colors = AppColors();
            // use state.uri.path as GoRouterState.location may not be available in this version
            final selected = _locToIndex(state.uri.path);

            return Scaffold(
              // the active page will render its own AppBar / body (child may contain its own Scaffold)
              body: child,
              floatingActionButton: FloatingActionButton(
                onPressed: () => GoRouter.of(context).pushNamed('addAccount', extra: {'asBottomSheet': true, 'account': null}),
                child: const Icon(Icons.add, size: 28),
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
              bottomNavigationBar: BottomAppBar(
                shape: const CircularNotchedRectangle(),
                notchMargin: 8,
                child: SizedBox(
                  height: 62,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: Icon(Icons.grid_view, color: selected == 0 ? colors.appbar_Color : Colors.grey),
                        onPressed: () => GoRouter.of(context).goNamed('dashboard'),
                      ),
                      IconButton(
                        icon: Icon(Icons.people, color: selected == 1 ? colors.appbar_Color : Colors.grey),
                        onPressed: () => GoRouter.of(context).goNamed('accounts'),
                      ),
                      const SizedBox(width: 48),
                      IconButton(
                        icon: Icon(Icons.analytics, color: selected == 2 ? colors.appbar_Color : Colors.grey),
                        onPressed: () => GoRouter.of(context).goNamed('analytics'),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: selected == 3 ? colors.appbar_Color : Colors.grey),
                        onPressed: () => GoRouter.of(context).goNamed('settings'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          routes: [
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
                return AccountFollowUpScreen(account: extra as Account);
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
                  barrierColor: Colors.black.withOpacity(0.15),
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
            GoRoute(
              name: 'analytics',
              path: '/analytics',
              pageBuilder: (context, state) {
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: const AnalyticsScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    final tween = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      ),
                    );
                  },
                );
              },
            ),
          ],
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
