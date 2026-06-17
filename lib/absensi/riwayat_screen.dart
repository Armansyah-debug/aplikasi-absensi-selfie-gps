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
    final isDosen = role == 'dosen';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Riwayat Absensi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ================= FILTER DATE =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF007AFF),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: Color(0xFF007AFF)),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMMM yyyy').format(selectedDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),

  // ================= DATA LIST =================
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                isAdmin
                    ? SupabaseService.getAllHistoryRaw()
                    : isDosen
                        ? SupabaseService.getDosenHistoryRaw(user.id)
                        : SupabaseService.getHistoryRaw(user.id),
                SupabaseService.getSesiList(),
                SupabaseService.getAllMK(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text('Gagal memuat data'));
                }

                final List<Map<String, dynamic>> rawAbsensi =
                    List<Map<String, dynamic>>.from(snapshot.data![0]);
                final List<Map<String, dynamic>> listSesi =
                    List<Map<String, dynamic>>.from(snapshot.data![1]);
                final List<Map<String, dynamic>> listMK =
                    List<Map<String, dynamic>>.from(snapshot.data![2]);

                print('RAW COUNT: ${rawAbsensi.length}');

                // ================= FILTER TANGGAL =================
                final filteredData = rawAbsensi.where((e) {
                  if (e['waktu'] == null) return false;

                  final t = DateTime.parse(e['waktu']).toLocal();

                  final match = (t.isAtSameMomentAs(startOfDay) ||
                          t.isAfter(startOfDay)) &&
                      t.isBefore(endOfDay);
                  return match;
                }).toList();

                if (filteredData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada data absensi',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                // ================= GROUPING DATA (MEMORY JOIN) =================
                final List<Map<String, dynamic>> groups = [];

                for (var item in filteredData) {
                  String namaMK = 'Absen Umum';
                  final sesiId = item['sesi_id'];

                  if (sesiId != null) {
                    final sesi = listSesi.firstWhere(
                      (s) => s['id'] == sesiId,
                      orElse: () => {},
                    );

                    if (sesi.isNotEmpty) {
                      final mkId = sesi['mata_kuliah_id'];
                      final mk = listMK.firstWhere(
                        (m) => m['id'] == mkId,
                        orElse: () => {},
                      );
                      if (mk.isNotEmpty) {
                        namaMK = mk['nama_mk'] ?? 'Absen Umum';
                      }
                    }
                  }

                  // Cari apakah grup sudah ada
                  final existingGroupIndex =
                      groups.indexWhere((g) => g['nama_mk'] == namaMK);

                  if (existingGroupIndex != -1) {
                    groups[existingGroupIndex]['items'].add(item);
                  } else {
                    groups.add({
                      'nama_mk': namaMK,
                      'items': [item],
                    });
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  itemBuilder: (context, gIndex) {
                    final group = groups[gIndex];
                    final String groupName = group['nama_mk'];
                    final List<Map<String, dynamic>> groupItems =
                        List<Map<String, dynamic>>.from(group['items']);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER GRUP
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 4, bottom: 12, top: 8),
                          child: Row(
                            children: [
                              Text(
                                "📚 $groupName",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${groupItems.length}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // DAFTAR CARD DALAM GRUP
                        ...groupItems.map((item) {
                          final id = item['id'];
                          final namaMahasiswa = item['nama'] ?? '-';
                          final npm = item['npm'] ?? '-';

                          final jenis = item['jenis'] ?? '-';
                          final alasan = item['alasan'] ?? '-';
                          final alamat = item['alamat'] ?? '-';
                          final isMocked = item['is_mocked'] == true;
                          String jam = '-';

                          if (item['waktu'] != null) {
                            try {
                              final dt =
                                  DateTime.parse(item['waktu']).toLocal();
                              jam = DateFormat('HH:mm').format(dt);
                            } catch (_) {}
                          }
                          final fotoPath = item['foto_path'];
                          final isHadir = jenis == 'Hadir';
                          final fotoUrl =
                              SupabaseService.getFotoUrl(fotoPath ?? '');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // FOTO
                                GestureDetector(
                                  onTap: fotoUrl.isNotEmpty
                                      ? () => _showImage(context, fotoUrl)
                                      : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: Colors.grey.shade100),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: fotoUrl.isNotEmpty
                                          ? Image.network(
                                              fotoUrl,
                                              width: 65,
                                              height: 65,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 65,
                                              height: 65,
                                              color: Colors.grey[50],
                                              child: Icon(Icons.person_rounded,
                                                  color: Colors.grey.shade400),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // DETAIL TEXT
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        namaMahasiswa,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        npm,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_rounded,
                                              size: 11, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              alamat,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isHadir
                                                  ? const Color(0xFF34C759)
                                                      .withOpacity(0.1)
                                                  : const Color(0xFFFF9500)
                                                      .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isHadir
                                                  ? "Hadir"
                                                  : "$jenis: $alasan",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isHadir
                                                    ? const Color(0xFF248A3D)
                                                    : const Color(0xFFC97600),
                                              ),
                                            ),
                                          ),
                                          if (isAdmin && isMocked) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.red.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                "FAKE GPS",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // TIME / ACTION
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      jam,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ),
                                    if (isAdmin)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded,
                                            color: Colors.red.shade400,
                                            size: 18),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                    title: const Text("Hapus?"),
                                                    content: const Text(
                                                        "Data akan dihapus permanen."),
                                                    actions: [
                                                      TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                          child: const Text(
                                                              "Batal")),
                                                      TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  true),
                                                          child: const Text(
                                                              "Hapus",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red))),
                                                    ],
                                                  ));
                                          if (confirm == true) {
                                            await SupabaseService.deleteAbsen(
                                                id,
                                                fotoPath: fotoPath);
                                            setState(() {});
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                      ],
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
