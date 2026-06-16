import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KelolaSesiScreen extends StatefulWidget {
  const KelolaSesiScreen({super.key});

  @override
  State<KelolaSesiScreen> createState() => _KelolaSesiScreenState();
}

class _KelolaSesiScreenState extends State<KelolaSesiScreen> {
  final supabase = Supabase.instance.client;

  Future<List<dynamic>> getSesi() async {
    print('GET SESI DIPANGGIL');

    final data = await supabase.from('sesi_absensi').select();

    print(data);

    return data;
  }

  Future<void> bukaSesi(int id) async {
    await supabase.from('sesi_absensi').update({'is_open': true}).eq('id', id);

    setState(() {});
  }

  Future<void> tutupSesi(int id) async {
    await supabase.from('sesi_absensi').update({'is_open': false}).eq('id', id);

    setState(() {});
  }

  String getNamaMK(int id) {
    switch (id) {
      case 1:
        return 'Pengolahan Citra Digital';
      case 2:
        return 'Pendidikan Akhlakul Karimah';
      case 3:
        return 'Technopreneurship';
      case 4:
        return 'Manajemen Proyek Perangkat Lunak';
      case 5:
        return 'Proyek Perangkat Lunak';
      case 6:
        return 'Big Data';
      default:
        return 'Mata Kuliah';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Kelola Sesi Absensi',
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
      body: FutureBuilder(
        future: getSesi(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
              ),
            );
          }

          final data = snapshot.data as List<dynamic>;

          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada sesi absensi',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final sesi = data[index];
              final isOpen = sesi['is_open'] ?? false;
              final mkName = getNamaMK(sesi['mata_kuliah_id']);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        color: isOpen
                            ? const Color(0xFF34C759).withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        child: Row(
                          children: [
                            Icon(
                              isOpen
                                  ? Icons.check_circle_rounded
                                  : Icons.pause_circle_rounded,
                              color: isOpen
                                  ? const Color(0xFF34C759)
                                  : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOpen ? 'SESI AKTIF' : 'SESI DITUTUP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isOpen
                                    ? const Color(0xFF248A3D)
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              sesi['tanggal'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mkName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _infoIcon(Icons.location_on_rounded,
                                    'Radius: ${sesi['radius_meter']}m'),
                                const SizedBox(width: 16),
                                _infoIcon(Icons.numbers_rounded,
                                    'ID: ${sesi['id']}'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isOpen
                                      ? const Color(0xFFFF3B30)
                                      : const Color(0xFF007AFF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  if (isOpen) {
                                    await tutupSesi(sesi['id']);
                                  } else {
                                    await bukaSesi(sesi['id']);
                                  }
                                },
                                child: Text(
                                  isOpen ? 'Tutup Absensi' : 'Buka Absensi',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
      ],
    );
  }
}
