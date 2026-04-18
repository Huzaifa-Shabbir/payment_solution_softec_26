
import 'dart:convert';
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.init();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment Solution Softec',
      // Use HomePage so you can run the customers query from the app/dashboard.
      home: const HomePage(),
    );
  }
}

// Add a simple UI to run the Supabase query and display results.
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _fetchCustomers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Make the response dynamic so static analysis won't assume a List.
      final dynamic res = await SupabaseService.client.from('customers').select();

      // Normalize possible response shapes (Map with 'data' or a raw List/Map).
      dynamic payload;
      if (res is Map<String, dynamic> && res.containsKey('data')) {
        // Safe: res is confirmed to be a Map before using string key access.
        payload = res['data'];
      } else {
        // Otherwise use the raw response (List, Map, etc.).
        payload = res;
      }

      final pretty = const JsonEncoder.withIndent('  ').convert(payload ?? {});
      setState(() => _result = pretty);
      debugPrint('Customers: $pretty');
    } catch (e, st) {
      debugPrint('Error fetching customers: $e\n$st');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Solution')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _fetchCustomers,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Fetch Customers'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _error != null
                      ? Text('Error: $_error', style: const TextStyle(color: Colors.red))
                      : Text(_result ?? 'Press "Fetch Customers" to run the query.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
>>>>>>> 95de49af0514a404faa573e0170f0ba9d1d418d2
