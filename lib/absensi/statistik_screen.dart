import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatistikScreen extends StatelessWidget {
  const StatistikScreen({super.key});

  Future<Map<String, int>> _fetchStats() async {
    final supabase = Supabase.instance.client;

    final hadir = await supabase.from('data_absensi').select().eq('jenis', 'Hadir');
    final izin = await supabase.from('data_absensi').select().eq('jenis', 'Izin');
    final cuti = await supabase.from('data_absensi').select().eq('jenis', 'Cuti');
    final sakit = await supabase.from('data_absensi').select().eq('jenis', 'Sakit');

    return {
      'Hadir': hadir.length,
      'Izin': izin.length,
      'Cuti': cuti.length,
      'Sakit': sakit.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        title: const Text("Statistik"),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _fetchStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final s = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card("Hadir", s['Hadir']!, Colors.green),
              _card("Izin", s['Izin']!, Colors.blue),
              _card("Cuti", s['Cuti']!, Colors.purple),
              _card("Sakit", s['Sakit']!, Colors.red),
            ],
          );
        },
      ),
    );
  }

  Widget _card(String title, int value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 14),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(value.toString(),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}