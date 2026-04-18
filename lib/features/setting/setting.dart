import 'package:flutter/material.dart';
import '../core/Theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode get _mode => ThemeController.instance.themeMode;

  void _setMode(ThemeMode m) {
    ThemeController.instance.setThemeMode(m);
    setState(() {}); // update local radio selection
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
         
          ListTile(
            title: const Text('Quick toggle'),
            subtitle: const Text('Switch between Light and Dark'),
            trailing: Switch(
              value: _mode == ThemeMode.dark,
              onChanged: (v) {
                ThemeController.instance.toggleBetweenLightDark();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }
}

