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
    if (mounted) setState(() => role = r ?? 'user');
  }

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
        title: Text(
          isAdmin ? 'Riwayat Absensi' : 'Riwayat Saya',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      body: FutureBuilder<List<dynamic>>(
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

          // ================= GROUPING BY MATA KULIAH =================
          final Map<int, List<Map<String, dynamic>>> mkGroups = {};
          
          for (var item in rawAbsensi) {
            final sesiId = item['sesi_id'];
            int mkId = -1; // Default for "Absen Umum"

            if (sesiId != null) {
              final sesi = listSesi.firstWhere(
                (s) => s['id'] == sesiId,
                orElse: () => {},
              );
              if (sesi.isNotEmpty) {
                mkId = sesi['mata_kuliah_id'] ?? -1;
              }
            }

            if (!mkGroups.containsKey(mkId)) {
              mkGroups[mkId] = [];
            }
            mkGroups[mkId]!.add(item);
          }

          // FILTER: HAPUS ABSEN UMUM DARI DAFTAR TAMPILAN
          final mkIdList = mkGroups.keys.where((id) => id != -1).toList();
          
          if (mkIdList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada data absensi mata kuliah',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mkIdList.length,
            itemBuilder: (context, gIndex) {
              final mkId = mkIdList[gIndex];
              final groupItems = mkGroups[mkId]!;
              
              final mkData = listMK.firstWhere(
                (m) => m['id'] == mkId,
                orElse: () => <String, dynamic>{},
              );
              final groupName = mkData['nama_mk'] ?? 'Mata Kuliah';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF007AFF)),
                    title: Text(
                      groupName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${groupItems.length}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: groupItems.map((item) {
                            final id = item['id'];
                            final namaMahasiswa = item['nama'] ?? '-';
                            final npm = item['npm'] ?? '-';
                            final jenis = item['jenis'] ?? 'Hadir';
                            final alasan = item['alasan'] ?? '-';
                            final alamat = item['alamat'] ?? '-';
                            final isMocked = item['is_mocked'] == true;
                            final isHadir = jenis == 'Hadir';

                            String jam = '-';
                            if (item['waktu'] != null) {
                              try {
                                final dt = DateTime.parse(item['waktu']).toLocal();
                                jam = DateFormat('HH:mm').format(dt);
                              } catch (_) {}
                            }
                            final fotoPath = item['foto_path'];
                            final fotoUrl = SupabaseService.getFotoUrl(fotoPath ?? '');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
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
                                        border: Border.all(color: Colors.grey.shade200),
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
                                                color: Colors.white,
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          namaMahasiswa,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          npm,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        
                                        // ROW LOKASI / TANGGAL
                                        Row(
                                          children: [
                                            Icon(
                                              isHadir ? Icons.location_on_rounded : Icons.calendar_today_rounded,
                                              size: 10, 
                                              color: Colors.grey
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                alamat, // Alamat atau Range Tanggal
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        // ROW ALASAN (HANYA IZIN/SAKIT)
                                        if (!isHadir) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.notes_rounded, size: 10, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  alasan,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade600,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],

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
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                jenis,
                                                style: TextStyle(
                                                  fontSize: 9,
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
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  "FAKE GPS",
                                                  style: TextStyle(
                                                    fontSize: 9,
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF007AFF),
                                        ),
                                      ),
                                      if (isAdmin)
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded,
                                              color: Colors.red.shade400, size: 16),
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
                                                                    context, false),
                                                            child: const Text("Batal")),
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context, true),
                                                            child: const Text("Hapus",
                                                                style: TextStyle(
                                                                    color:
                                                                        Colors.red))),
                                                      ],
                                                    ));
                                            if (confirm == true) {
                                              await SupabaseService.deleteAbsen(id,
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
                        ),
                      ),
                      const SizedBox(height: 8),
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
