import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/core/Theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final AppColors colors = AppColors(); // Instance of your color palette

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
      context.go('/login'); // change route if needed
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.Background, // Use background color
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors().splash_Screen, // Splash screen base color
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: colors.secondary_Text,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.Border.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 3,
                    )
                  ],
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 60,
                  color: colors.primary_Text, // Accent from your palette
                ),
              ),

              const SizedBox(height: 25),

              // App Name
              Text(
                "SmartPay Reminder",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: colors.secondary_Text,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Stay on top of your payments",
                style: TextStyle(
                  fontSize: 14,
                  color: colors.primary_Text,
                ),
              ),

              const SizedBox(height: 40),

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
