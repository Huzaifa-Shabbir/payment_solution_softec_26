import 'dart:developer';
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment Solution Softec',
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> customers = [];
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      // New Supabase Dart syntax: no .execute()
      final response = await SupabaseService.client
          .from('customers')
          .select();

      setState(() {
        customers = response as List<dynamic>;
        isLoading = false;
      });

      log('Fetched ${customers.length} customers');
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      log('Error fetching customers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Text(
          'Error: $errorMessage',
          style: const TextStyle(color: Colors.red),
        ),
      )
          : customers.isEmpty
          ? const Center(child: Text('No customers found'))
          : ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return Card(
            child: ListTile(
              title: Text(customer['name'] ?? 'Unnamed'),
              subtitle: Text(customer['email'] ?? 'No email'),
              trailing: Text(customer['status'] ?? 'Unknown'),
            ),
          );
        },
      ),
    );
  }
}
