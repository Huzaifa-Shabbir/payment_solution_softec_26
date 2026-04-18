import 'dart:async';
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'splash_Screen.dart';
import 'features/core/Theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment Solution Softec',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme:  ColorScheme.dark(
          primary: AppColors().Background, // Use your background color as primary
          secondary: Colors.cyanAccent,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

