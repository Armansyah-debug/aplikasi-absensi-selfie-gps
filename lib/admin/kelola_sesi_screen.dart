import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class KelolaSesiScreen extends StatefulWidget {
  const KelolaSesiScreen({super.key});

  @override
  State<KelolaSesiScreen> createState() => _KelolaSesiScreenState();
}

class _KelolaSesiScreenState extends State<KelolaSesiScreen> {
  final supabase = Supabase.instance.client;

  // New State for Academic Dropdowns
  List<dynamic> listMK = [];
  List<dynamic> listKelas = [];
  List<dynamic> listPertemuan = [];

  String? selectedMK;
  String? selectedKelas;
  String? selectedPertemuan;

  bool loadingMK = false;
  bool loadingKelas = false;
  bool loadingPertemuan = false;
  bool loadingSubmit = false;

  @override
  void initState() {
    super.initState();
    _fetchMK();
  }

  Future<void> _fetchMK() async {
    setState(() => loadingMK = true);
    print('DEBUG _fetchMK dipanggil');

    final user = supabase.auth.currentUser;
    if (user != null) {
      final role = await SupabaseService.getUserRole(user.id);
      print('ROLE USER: $role');
      print('USER ID: ${user.id}');

      List<Map<String, dynamic>> data;
      if (role == 'dosen') {
        data = await SupabaseService.getMataKuliah(dosenId: user.id);
      } else {
        data = await SupabaseService.getMataKuliah();
      }

      print('MK COUNT: ${data.length}');
      setState(() {
        listMK = data;
        loadingMK = false;
      });
    } else {
      setState(() => loadingMK = false);
    }
  }

  Future<void> _fetchKelas(String mkId) async {
    setState(() {
      loadingKelas = true;
      listKelas = [];
      selectedKelas = null;
      listPertemuan = [];
      selectedPertemuan = null;
    });
    final data = await SupabaseService.getKelasByMK(mkId);
    setState(() {
      listKelas = data;
      loadingKelas = false;
    });
  }

  Future<void> _fetchPertemuan(String kelasId) async {
    setState(() {
      loadingPertemuan = true;
      listPertemuan = [];
      selectedPertemuan = null;
    });
    final data = await SupabaseService.getPertemuanByKelas(kelasId);
    setState(() {
      listPertemuan = data;
      loadingPertemuan = false;
    });
  }

  Future<void> _handleBukaSesiBaru() async {
    if (selectedMK == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Mata Kuliah dulu')),
      );
      return;
    }

    setState(() => loadingSubmit = true);
    try {
      await SupabaseService.createSesiAbsensi(
        mkId: selectedMK!,
        pertemuanId: selectedPertemuan, // Bisa null untuk saat ini
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi absensi baru berhasil dibuka')),
      );
      // Reset selections
      setState(() {
        selectedMK = null;
        selectedKelas = null;
        selectedPertemuan = null;
        listKelas = [];
        listPertemuan = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal buka sesi: $e')),
      );
    } finally {
      setState(() => loadingSubmit = false);
    }
  }

  Future<List<dynamic>> getSesi() async {
    print('GET SESI DIPANGGIL');

    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final role = await SupabaseService.getUserRole(user.id);
    print('ROLE USER: $role');

    var query = supabase.from('sesi_absensi').select();

    if (role == 'dosen') {
      final mkIds = listMK.map((e) => e['id']).toList();
      print('MK DOSEN: $mkIds');
      // Menggunakan filter generik 'in' untuk kompatibilitas versi
      query = query.filter('mata_kuliah_id', 'in', mkIds);
    }

    final data = await query;
    print('SESI COUNT: ${data.length}');

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

  String _formatTanggal(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      final year = parts[0];
      final month = parts[1];
      final day = parts[2];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '$day ${months[int.parse(month) - 1]} $year';
    } catch (e) {
      return dateStr;
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
      body: Column(
        children: [
          // ================= FORM BUKA SESI BARU =================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buka Absensi Baru',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DROPDOWN MATA KULIAH
                  DropdownButtonFormField<String>(
                    value: selectedMK,
                    hint: const Text('Pilih Mata Kuliah'),
                    isExpanded: true,
                    items: listMK.map((e) {
                      return DropdownMenuItem<String>(
                        value: e['id'].toString(),
                        child: Text(e['nama_mk'] ?? '-'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedMK = val);
                        // _fetchKelas(val); // Nonaktifkan untuk sementara
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // const SizedBox(height: 12),

                  // DROPDOWN KELAS (DISEMBUNYIKAN SEMENTARA)
                  /*
                  DropdownButtonFormField<String>(
                    value: selectedKelas,
                    hint: Text(loadingKelas ? 'Memuat...' : 'Pilih Kelas'),
                    isExpanded: true,
                    items: listKelas.map((e) {
                      return DropdownMenuItem<String>(
                        value: e['id'].toString(),
                        child: Text(e['nama_kelas'] ?? '-'),
                      );
                    }).toList(),
                    onChanged: selectedMK == null
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => selectedKelas = val);
                              _fetchPertemuan(val);
                            }
                          },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  */

                  // DROPDOWN PERTEMUAN (DISEMBUNYIKAN SEMENTARA)
                  /*
                  DropdownButtonFormField<String>(
                    value: selectedPertemuan,
                    hint:
                        Text(loadingPertemuan ? 'Memuat...' : 'Pilih Pertemuan'),
                    isExpanded: true,
                    items: listPertemuan.map((e) {
                      return DropdownMenuItem<String>(
                        value: e['id'].toString(),
                        child: Text('Pertemuan Ke-${e['pertemuan_ke']}'),
                      );
                    }).toList(),
                    onChanged: selectedKelas == null
                        ? null
                        : (val) {
                            setState(() => selectedPertemuan = val);
                          },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  */
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          loadingSubmit ? null : () => _handleBukaSesiBaru(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loadingSubmit
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Buka Absensi Baru',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ================= LIST SESI (EXISTING) =================
          Expanded(
            child: FutureBuilder(
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

                // FILTER HANYA SESI AKTIF DI TINGKAT UI
                final activeSesi =
                    data.where((e) => e['is_open'] == true).toList();

                if (activeSesi.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada sesi aktif',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeSesi.length,
                  itemBuilder: (context, index) {
                    final sesi = activeSesi[index];
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
                                    _formatTanggal(sesi['tanggal']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
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
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                        isOpen
                                            ? 'Tutup Absensi'
                                            : 'Buka Absensi',
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
          ),
        ],
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