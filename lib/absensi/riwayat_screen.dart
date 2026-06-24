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
  String _activeFilter = 'Bulan Ini';

  // Dosen Redesign Search & Filter
  String _dosenSearchQuery = '';
  int? _dosenSelectedMKId;

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
          (isAdmin || isDosen) ? (isAdmin ? 'Riwayat Absensi Global' : 'Riwayat Kehadiran Saya') : 'UniCheck',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.6,
            color: Color(0xFF1A1D20),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1D20),
        elevation: 0,
        centerTitle: false,
        leading: (isAdmin || isDosen)
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFF1F2F6),
                  child: Icon(Icons.person_outline_rounded, color: Color(0xFF1A1D20), size: 20),
                ),
              ),
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

          // ================= MAHASISWA REDESIGN VIEW =================
          if (!isAdmin && !isDosen) {
            return _buildMahasiswaHistoryView(rawAbsensi, listSesi, listMK);
          }

          // ================= DOSEN REDESIGN VIEW =================
          if (isDosen) {
            return _buildDosenHistoryView(rawAbsensi, listSesi, listMK);
          }

          // ================= GROUPING BY MATA KULIAH (ADMIN) =================
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

  // ================= MAHASISWA HISTORY VIEW =================
  Widget _buildMahasiswaHistoryView(
    List<Map<String, dynamic>> rawAbsensi,
    List<Map<String, dynamic>> listSesi,
    List<Map<String, dynamic>> listMK,
  ) {
    // 1. Filter out Absen Umum
    final filteredAbsensi = rawAbsensi.where((item) {
      final sesiId = item['sesi_id'];
      if (sesiId == null) return false;
      final sesi = listSesi.firstWhere((s) => s['id'] == sesiId, orElse: () => {});
      return sesi.isNotEmpty && sesi['mata_kuliah_id'] != null;
    }).toList();

    // 2. Apply Pill Filter (Bulan Ini / Semester Ini)
    final now = DateTime.now();
    final displayedAbsensi = filteredAbsensi.where((item) {
      if (_activeFilter == 'Bulan Ini') {
        if (item['waktu'] == null) return false;
        try {
          final dt = DateTime.parse(item['waktu']).toLocal();
          return dt.month == now.month && dt.year == now.year;
        } catch (_) {
          return false;
        }
      }
      return true; // "Semester Ini" or "Pilih Rentang" shows all
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Filter Button Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Riwayat",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rekap absensi perkuliahan Anda.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Horizontal filter pills
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Bulan Ini', 'Semester Ini', 'Pilih Rentang'].map((pill) {
                final isSelected = _activeFilter == pill;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _activeFilter = pill),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4343D9) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF4343D9) : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        pill,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Flat Card List
        Expanded(
          child: displayedAbsensi.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        "Tidak ada riwayat untuk periode ini.",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: displayedAbsensi.length,
                  itemBuilder: (context, index) {
                    final item = displayedAbsensi[index];
                    final sesiId = item['sesi_id'];
                    final sesi = listSesi.firstWhere((s) => s['id'] == sesiId, orElse: () => {});
                    final mkId = sesi['mata_kuliah_id'];
                    final mk = listMK.firstWhere((m) => m['id'] == mkId, orElse: () => {});
                    final namaMK = mk['nama_mk'] ?? 'Mata Kuliah';
                    final jenis = item['jenis'] ?? 'Hadir';
                    final ruangan = sesi['ruangan'] ?? 'Lab Komputer 03';

                    // Parse date and time
                    String tglStr = '-';
                    String jamRangeStr = '08:00 - 09:40';
                    String jamAbsen = '-';
                    if (item['waktu'] != null) {
                      try {
                        final dt = DateTime.parse(item['waktu']).toLocal();
                        final weekday = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][dt.weekday - 1];
                        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
                        tglStr = "$weekday, ${dt.day} ${months[dt.month - 1]} ${dt.year}";
                        jamAbsen = DateFormat('HH:mm').format(dt);
                        
                        final startHour = sesi['jam_mulai'] ?? '08:00';
                        final endHour = sesi['jam_selesai'] ?? '09:40';
                        jamRangeStr = "$startHour - $endHour";
                      } catch (_) {}
                    }

                    // Capitalized soft badges
                    Color badgeBg = const Color(0xFFE8F5E9);
                    Color badgeText = const Color(0xFF2E7D32);
                    String badgeLabel = 'HADIR';

                    if (jenis == 'Izin') {
                      badgeBg = const Color(0xFFFFF8E1);
                      badgeText = const Color(0xFFF57F17);
                      badgeLabel = 'IZIN';
                    } else if (jenis == 'Sakit') {
                      badgeBg = const Color(0xFFFFEBEE);
                      badgeText = const Color(0xFFC62828);
                      badgeLabel = 'SAKIT';
                    } else if (jenis == 'Pelanggaran') {
                      badgeBg = const Color(0xFFFFEBEE);
                      badgeText = const Color(0xFFC62828);
                      badgeLabel = 'DITOLAK';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  namaMK,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1D20),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                tglStr,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                jamRangeStr,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ruangan,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () => _showDetailBottomSheet(context, item, namaMK, jamAbsen),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  child: Row(
                                    children: const [
                                      Text(
                                        "Detail",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4343D9),
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF4343D9)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ================= DETAIL BOTTOM SHEET =================
  void _showDetailBottomSheet(BuildContext context, Map<String, dynamic> item, String namaMK, String jamAbsen) {
    final fotoPath = item['foto_path'];
    final fotoUrl = SupabaseService.getFotoUrl(fotoPath ?? '');
    final alamat = item['alamat'] ?? '-';
    final jenis = item['jenis'] ?? 'Hadir';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Detail Presensi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1D20)),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      color: Colors.grey.shade50,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: fotoUrl.isNotEmpty
                          ? Image.network(fotoUrl, fit: BoxFit.cover)
                          : const Icon(Icons.person_rounded, size: 40, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          namaMK,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1D20)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              "Status: $jenis",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              "Jam: $jamAbsen WIB",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "LOKASI TERVERIFIKASI",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF4343D9)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alamat,
                        style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1A1D20)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
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

  // ================= DOSEN REDESIGN VIEW =================
  Widget _buildDosenHistoryView(
    List<Map<String, dynamic>> rawAbsensi,
    List<Map<String, dynamic>> listSesi,
    List<Map<String, dynamic>> listMK,
  ) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox();

    // 1. Get lecturer's Mata Kuliah list
    final dosenMKs = listMK.where((mk) => mk['dosen_id'] == user.id).toList();
    final dosenMKIds = dosenMKs.map((e) => e['id'] as int).toSet();

    // 2. Get sessions belonging to these Mata Kuliahs
    final dosenSesiList = listSesi.where((sesi) {
      final mkId = sesi['mata_kuliah_id'];
      if (mkId == null) return false;
      return dosenMKIds.contains(mkId);
    }).toList();

    // 3. Filter by selected Mata Kuliah chip
    var filteredSesi = dosenSesiList;
    if (_dosenSelectedMKId != null) {
      filteredSesi = filteredSesi.where((s) => s['mata_kuliah_id'] == _dosenSelectedMKId).toList();
    }

    // 4. Filter by Search Query
    if (_dosenSearchQuery.isNotEmpty) {
      filteredSesi = filteredSesi.where((s) {
        final mk = listMK.firstWhere((m) => m['id'] == s['mata_kuliah_id'], orElse: () => {});
        final mkName = (mk['nama_mk'] ?? '').toString().toLowerCase();
        return mkName.contains(_dosenSearchQuery.toLowerCase());
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Semester Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Riwayat Presensi",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Daftar riwayat sesi perkuliahan Anda.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Semester Ganjil ${DateTime.now().year}",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4343D9),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _dosenSearchQuery = val),
              decoration: InputDecoration(
                hintText: "Cari sesi atau mata kuliah...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Filter Pills
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "Semua Sesi" pill
                GestureDetector(
                  onTap: () => setState(() => _dosenSelectedMKId = null),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _dosenSelectedMKId == null ? const Color(0xFF4343D9) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _dosenSelectedMKId == null ? const Color(0xFF4343D9) : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      "Semua Sesi",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _dosenSelectedMKId == null ? FontWeight.bold : FontWeight.w500,
                        color: _dosenSelectedMKId == null ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                // Mata Kuliah pills
                ...dosenMKs.map((mk) {
                  final mkId = mk['id'] as int;
                  final isSelected = _dosenSelectedMKId == mkId;
                  final mkName = mk['nama_mk'] ?? 'Mata Kuliah';
                  return GestureDetector(
                    onTap: () => setState(() => _dosenSelectedMKId = mkId),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4343D9) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF4343D9) : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        mkName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // List Kronologis Sesi
        Expanded(
          child: filteredSesi.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        "Tidak ada riwayat sesi ditemukan.",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: filteredSesi.length,
                  itemBuilder: (context, index) {
                    final sesi = filteredSesi[index];
                    final mkId = sesi['mata_kuliah_id'];
                    final mk = listMK.firstWhere((m) => m['id'] == mkId, orElse: () => {});
                    final namaMK = mk['nama_mk'] ?? 'Mata Kuliah';
                    final ruangan = sesi['ruangan'] ?? 'Ruang Kelas';

                    // Find total check-ins in rawAbsensi for this session
                    final sessionCheckIns = rawAbsensi.where((item) => item['sesi_id'] == sesi['id'] && item['jenis'] != 'Pelanggaran').toList();
                    final checkInCount = sessionCheckIns.length;
                    
                    // Ratio estimation
                    final classSize = checkInCount > 35 ? checkInCount : 40; 

                    // Status and styling
                    Color badgeBg = const Color(0xFFE8F5E9);
                    Color badgeText = const Color(0xFF2E7D32);
                    String badgeLabel = 'HADIR';

                    final ratio = checkInCount / classSize;
                    if (ratio >= 0.95) {
                      badgeBg = const Color(0xFFE8F5E9);
                      badgeText = const Color(0xFF2E7D32);
                      badgeLabel = 'SEMPURNA';
                    } else if (ratio < 0.75) {
                      badgeBg = const Color(0xFFFFEBEE);
                      badgeText = const Color(0xFFC62828);
                      badgeLabel = 'RENDAH';
                    } else {
                      badgeBg = const Color(0xFFE8E8FF);
                      badgeText = const Color(0xFF4343D9);
                      badgeLabel = 'HADIR';
                    }

                    // Format date
                    String tglStr = '-';
                    String jamRangeStr = '08:00 - 10:30';
                    if (sesi['tanggal'] != null) {
                      try {
                        final dt = DateTime.parse(sesi['tanggal']).toLocal();
                        final weekday = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][dt.weekday - 1];
                        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
                        tglStr = "$weekday, ${dt.day} ${months[dt.month - 1]} ${dt.year}";

                        final startHour = sesi['jam_mulai'] ?? '08:00';
                        final endHour = sesi['jam_selesai'] ?? '10:30';
                        jamRangeStr = "$startHour - $endHour";
                      } catch (_) {}
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  namaMK,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1D20),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                tglStr,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                jamRangeStr,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ruangan,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "$checkInCount/$classSize Hadir",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4343D9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
