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
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User belum login')),
      );
    }

    final isAdmin = role == 'admin';
    final isDosen = role == 'dosen';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Riwayat Absensi Global' : 'Riwayat Kehadiran Saya',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
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

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
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
                  Icon(Icons.history_toggle_off_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada data absensi mata kuliah',
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: mkIdList.length,
            itemBuilder: (context, gIndex) {
              final mkId = mkIdList[gIndex];
              final groupItems = mkGroups[mkId]!;
              
              final mkData = listMK.firstWhere(
                (m) => m['id'] == mkId,
                orElse: () => <String, dynamic>{},
              );
              final groupName = mkData['nama_mk'] ?? 'Mata Kuliah';
              final groupJurusan = mkData['jurusan'] ?? '-';
              final groupSemester = mkData['semester']?.toString() ?? '-';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                      child: Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary, size: 20),
                    ),
                    title: Text(
                      groupName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      "$groupJurusan • Sem $groupSemester",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${groupItems.length}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                            final sesi = listSesi.firstWhere(
                              (s) => s['id'] == item['sesi_id'],
                              orElse: () => {},
                            );
                            final pertemuanKe = sesi['pertemuan_ke'];
                            final materi = sesi['materi'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Row(
                                children: [
                                  // FOTO / ICON
                                  GestureDetector(
                                    onTap: fotoUrl.isNotEmpty
                                        ? () => _showImage(context, fotoUrl)
                                        : null,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: fotoUrl.isNotEmpty
                                            ? Image.network(
                                                fotoUrl,
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                width: 56,
                                                height: 56,
                                                color: Colors.white,
                                                child: Icon(Icons.person_rounded,
                                                    color: Colors.grey.shade400, size: 24),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // DETAIL TEXT
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isAdmin || isDosen) ...[
                                          Text(
                                            namaMahasiswa,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            npm,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        if (pertemuanKe != null) ...[
                                          Text(
                                            'Pertemuan Ke-$pertemuanKe',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        if (materi != null && materi.isNotEmpty) ...[
                                          Text(
                                            'Materi: $materi',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        // ROW LOKASI / TANGGAL
                                        Row(
                                          children: [
                                            Icon(
                                              isHadir ? Icons.location_on_rounded : Icons.calendar_today_rounded,
                                              size: 11, 
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                alamat,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (!isHadir && alasan.isNotEmpty && alasan != '-') ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.notes_rounded, size: 11, color: Colors.grey.shade500),
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
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isHadir
                                                    ? const Color(0xFF94D2BD).withOpacity(0.2)
                                                    : jenis == 'Izin'
                                                        ? const Color(0xFF007AFF).withOpacity(0.1)
                                                        : const Color(0xFFEE9B00).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                jenis,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isHadir
                                                      ? const Color(0xFF0A9396)
                                                      : jenis == 'Izin'
                                                          ? const Color(0xFF0051D5)
                                                          : const Color(0xFFCA6702),
                                                ),
                                              ),
                                            ),
                                            if (isAdmin && isMocked) ...[
                                              const SizedBox(width: 6),
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
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      if (isAdmin)
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded,
                                              color: Colors.red.shade400, size: 18),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                      title: const Text("Hapus Data?"),
                                                      content: const Text(
                                                          "Data absensi ini akan dihapus secara permanen."),
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
