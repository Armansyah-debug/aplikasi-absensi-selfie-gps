import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _primaryBlue = Color(0xFF1976D2);

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

  Widget _statCard({
    required IconData icon,
    required String title,
    required int value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Statistik Absensi'),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _fetchStats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Terjadi kesalahan',
                style: TextStyle(color: Colors.red.shade400),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statCard(
                icon: Icons.check_circle,
                title: 'Hadir',
                value: stats['Hadir'] ?? 0,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 12),
              _statCard(
                icon: Icons.assignment_turned_in,
                title: 'Izin',
                value: stats['Izin'] ?? 0,
                color: _primaryBlue,
              ),
              const SizedBox(height: 12),
              _statCard(
                icon: Icons.event_available,
                title: 'Cuti',
                value: stats['Cuti'] ?? 0,
                color: Colors.purple.shade600,
              ),
              const SizedBox(height: 12),
              _statCard(
                icon: Icons.sick,
                title: 'Sakit',
                value: stats['Sakit'] ?? 0,
                color: Colors.red.shade600,
              ),
            ],
          );
        },
      ),
    );
  }
}
