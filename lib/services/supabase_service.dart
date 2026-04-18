import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> init() async {
    await Supabase.initialize(
      url: "https://xidsjmrrxlniqsdipkvg.supabase.co",
      anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhpZHNqbXJyeGxuaXFzZGlwa3ZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNDg5MTgsImV4cCI6MjA5MTkyNDkxOH0.tu45WoUgeAlVvVc8zJ1OBTwOYut-b3mCHYrlUud8KjY",
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}