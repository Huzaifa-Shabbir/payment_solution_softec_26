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
import 'package:flutter/services.dart';

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
            final selected = _locToIndex(state.uri.path);

            return Scaffold(
              // the active page will render its own AppBar / body (child may contain its own Scaffold)
              body: child,
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  // Prevent multiple sheet openings - check if already on add route
                  if (GoRouter.of(context).state?.name != 'addAccount') {
                    GoRouter.of(context).pushNamed('addAccount', extra: {'asBottomSheet': true, 'account': null});
                  }
                },
                child: const Icon(Icons.add, size: 28),
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
              bottomNavigationBar: BottomAppBar(
                shape: const CircularNotchedRectangle(),
                notchMargin: 8,
                elevation: 8,
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBottomNavItem(
                        context: context,
                        icon: Icons.grid_view,
                        isSelected: selected == 0,
                        onTap: () {
                          if (selected != 0) {
                            HapticFeedback.lightImpact();
                            GoRouter.of(context).goNamed('dashboard');
                          }
                        },
                        colors: colors,
                      ),
                      _buildBottomNavItem(
                        context: context,
                        icon: Icons.people,
                        isSelected: selected == 1,
                        onTap: () {
                          if (selected != 1) {
                            HapticFeedback.lightImpact();
                            GoRouter.of(context).goNamed('accounts');
                          }
                        },
                        colors: colors,
                      ),

                      // cleaner FAB spacing
                      const SizedBox(width: 56),

                      _buildBottomNavItem(
                        context: context,
                        icon: Icons.analytics,
                        isSelected: selected == 2,
                        onTap: () {
                          if (selected != 2) {
                            HapticFeedback.lightImpact();
                            GoRouter.of(context).goNamed('analytics');
                          }
                        },
                        colors: colors,
                      ),
                      _buildBottomNavItem(
                        context: context,
                        icon: Icons.settings,
                        isSelected: selected == 3,
                        onTap: () {
                          if (selected != 3) {
                            HapticFeedback.lightImpact();
                            GoRouter.of(context).goNamed('settings');
                          }
                        },
                        colors: colors,
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

    // Use only the light theme everywhere; remove dark theme / system theme switching.
    return AccountStoreProvider(
      store: accountStore,
      child: MaterialApp.router(
        title: 'Payment Solution Softec',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        routerConfig: router,
        theme: AppTheme.light(),
      ),
    );
  }

  /// Build a redesigned bottom nav item with highlight effect
  Widget _buildBottomNavItem({
    required BuildContext context,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return Expanded(
        child: Center( // 👈 keeps it centered instead of stretched
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8), // 👈 tighter box
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.appbar_Color.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10), // 👈 smaller radius
              ),
              child: Icon(
                icon,
                color: isSelected ? colors.appbar_Color : Colors.grey,
                size: isSelected ? 26 : 24,
              ),
            ),
          ),
        ),
    );
  }
}
