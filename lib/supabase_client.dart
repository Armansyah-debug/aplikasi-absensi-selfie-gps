import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientConfig {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://vqeedgzeamkzkxrrautk.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxZWVkZ3plYW1remt4cnJhdXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NjM2NzMsImV4cCI6MjA4MzEzOTY3M30.OFOvsB5UaFAT52ZGlS9cW8X5bglXT1WhSG_s7B_LR3c',
    );
  }

  static SupabaseClient get instance => Supabase.instance.client;
}