import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatistikScreen extends StatelessWidget {
  const StatistikScreen({super.key});

  Future<Map<String, int>> _fetchStats() async {
    final supabase = Supabase.instance.client;

    final hadir =
        await supabase.from('data_absensi').select().eq('jenis', 'Hadir');
    final izin =
        await supabase.from('data_absensi').select().eq('jenis', 'Izin');
    final cuti =
        await supabase.from('data_absensi').select().eq('jenis', 'Cuti');
    final sakit =
        await supabase.from('data_absensi').select().eq('jenis', 'Sakit');

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
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          "Statistik Kehadiran",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _fetchStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final s = snapshot.data!;
          final total =
              s['Hadir']! + s['Izin']! + s['Cuti']! + s['Sakit']!;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _overviewCard(total),
              const SizedBox(height: 24),
              const Text(
                "Rincian Data",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _card("Hadir", s['Hadir']!, const Color(0xFF34C759)),
              _card("Izin", s['Izin']!, const Color(0xFF007AFF)),
              _card("Cuti", s['Cuti']!, const Color(0xFF5856D6)),
              _card("Sakit", s['Sakit']!, const Color(0xFFFF3B30)),
            ],
          );
        },
      ),
    );
  }

  Widget _overviewCard(int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF0056B3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Data",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$total",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Entri terdaftar dalam sistem",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, int value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bar_chart_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}