import 'dart:async';
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'splash_Screen.dart';
import 'features/core/Theme.dart';
import 'services/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  await LocalStorage.init();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment Solution Softec',
      debugShowCheckedModeBanner: false,

      home: const SplashScreen(),
    );
  }
}
