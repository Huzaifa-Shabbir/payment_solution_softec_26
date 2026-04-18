import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/core/Theme.dart';
import 'features/dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Navigate after 3 seconds
    Timer(const Duration(seconds: 3), () {
      // use go_router named navigation
      context.goNamed('dashboard');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.splash_Screen,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: colors.secondary_Text,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.Border.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 60,
                  color: colors.appbar_Color,
                ),
              ),
              const SizedBox(height: 20),
              Text("SmartPay",
                  style: textTheme.titleLarge
                      ?.copyWith(color: colors.secondary_Text)),
              const SizedBox(height: 8),
              Text("Stay on top of your payments",
                  style: textTheme.bodyMedium?.copyWith(
                      color: colors.secondary_Text.withOpacity(0.9))),
              const SizedBox(height: 26),
              CircularProgressIndicator(
                color: colors.secondary_Text,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
