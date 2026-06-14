import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  DateTime selectedDate = DateTime.now();
  String role = 'user';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final r = await SupabaseService.getUserRole(user.id);
    setState(() => role = r ?? 'user');
  }

  DateTime get startOfDay =>
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  DateTime get endOfDay => startOfDay.add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User belum login')),
      );
    }

    final isAdmin = role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text('Riwayat (${role.toUpperCase()})'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ================= FILTER DATE =================
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );

                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "📅 ${DateFormat('dd MMM yyyy').format(selectedDate)}",
                ),
              ),
            ),
          ),

          // ================= STREAM =================
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: isAdmin
                  ? SupabaseService.streamAllData()
                  : SupabaseService.streamMyData(user.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var data = snapshot.data!;

                // ================= FILTER TANGGAL =================
                data = data.where((e) {
                  if (e['waktu'] == null) return false;

                  final t = DateTime.parse(e['waktu']).toLocal();

                  return (t.isAtSameMomentAs(startOfDay) ||
                          t.isAfter(startOfDay)) &&
                      t.isBefore(endOfDay);
                }).toList();

                if (data.isEmpty) {
                  return const Center(child: Text('Tidak ada data'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];

                    final id = item['id'];
                    final nama = item['nama'] ?? '-';
                    final npm = item['npm'] ?? '-';
                    final jenis = item['jenis'] ?? '-';
                    final alasan = item['alasan'] ?? '-';
                    String waktu = '-';

                    if (item['waktu'] != null) {
                      try {
                        waktu = DateFormat(
                          'dd MMM yyyy HH:mm',
                        ).format(
                          DateTime.parse(item['waktu']).toLocal(),
                        );
                      } catch (_) {}
                    }
                    final fotoPath = item['foto_path'];

                    final isHadir = jenis == 'Hadir';

                    final fotoUrl = SupabaseService.getFotoUrl(fotoPath ?? '');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          // ================= FOTO =================
                          GestureDetector(
                            onTap: fotoUrl.isNotEmpty
                                ? () => _showImage(context, fotoUrl)
                                : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: fotoUrl.isNotEmpty
                                  ? Image.network(
                                      fotoUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image),
                                    ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // ================= TEXT =================
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "$nama ($npm)",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isHadir ? "📍 Hadir" : "📝 $jenis - $alasan",
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "🕒 $waktu",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ================= DELETE (ADMIN ONLY) =================
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Hapus Data?"),
                                    content: const Text(
                                      "Data + foto akan dihapus",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Batal"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Hapus"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await SupabaseService.deleteAbsen(
                                    id,
                                    fotoPath: fotoPath,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Berhasil dihapus"),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= IMAGE PREVIEW =================
  void _showImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }
}
