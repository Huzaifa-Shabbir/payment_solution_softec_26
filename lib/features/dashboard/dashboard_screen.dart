import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SmartPay"),
      ),
      body: const Center(
        child: Text(
          "Welcome to the Dashboard!",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
