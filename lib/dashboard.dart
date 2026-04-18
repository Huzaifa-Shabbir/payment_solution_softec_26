import 'dart:developer';
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<dynamic> customers = [];
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  /// =======================
  /// FETCH DATA FROM SUPABASE
  /// =======================
  Future<void> _loadCustomers() async {
    try {
      final response =
      await SupabaseService.client.from('customers').select();

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

  /// =======================
  /// UI
  /// =======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.black87,
      ),
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
          ? const Center(
        child: Text('No customers found'),
      )
          : ListView.builder(
        itemCount: customers.length,
        padding: const EdgeInsets.all(10),
        itemBuilder: (context, index) {
          final customer = customers[index];

          return Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(
                customer['name'] ?? 'Unnamed',
                style: const TextStyle(
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                customer['email'] ?? 'No email',
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  customer['status'] ?? 'Unknown',
                  style: const TextStyle(
                      color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}