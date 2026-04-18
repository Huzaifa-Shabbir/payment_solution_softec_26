import 'package:flutter/material.dart';
import 'package:payment_solution_softec_26/features/core/Theme.dart';
import '../accounts/account_list_screen.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors().Background,
      appBar: AppBar(
        title: Text("SmartPay",style:TextStyle(color: AppColors().secondary_Text,fontSize: 24,fontWeight: FontWeight.bold)),

        backgroundColor: AppColors().appbar_Color,

      ),
      body: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome to the Dashboard!",
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.account_circle),
              label: const Text('Accounts'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountListScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
