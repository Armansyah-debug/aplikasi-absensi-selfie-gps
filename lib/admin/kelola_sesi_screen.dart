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

  // State for MK Dropdown
  List<dynamic> listMK = [];
  String? selectedMK;

  // State for new fields
  final _materiController = TextEditingController();
  int? _selectedPertemuanKe;

  bool loadingMK = false;
  bool loadingSubmit = false;

  @override
  void initState() {
    super.initState();
    _fetchMK();
  }

  @override
  void dispose() {
    _materiController.dispose();
    super.dispose();
  }

  Future<void> _fetchMK() async {
    setState(() => loadingMK = true);
    final user = supabase.auth.currentUser;
    if (user != null) {
      final role = await SupabaseService.getUserRole(user.id);
      List<Map<String, dynamic>> data;
      if (role == 'dosen') {
        data = await SupabaseService.getMataKuliah(dosenId: user.id);
      } else {
        data = await SupabaseService.getMataKuliah();
      }
      setState(() {
        listMK = data;
        loadingMK = false;
      });
    } else {
      setState(() => loadingMK = false);
    }
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
      final mk = listMK.firstWhere((e) => e['id'].toString() == selectedMK);
      final jurusan = mk['jurusan'];
      final semester = mk['semester'];

      final existingSesi = await supabase
          .from('sesi_absensi')
          .select('id, mata_kuliah!inner(jurusan, semester)')
          .eq('is_open', true)
          .eq('mata_kuliah.jurusan', jurusan)
          .eq('mata_kuliah.semester', semester)
          .maybeSingle();

      if (existingSesi != null) {
        throw 'Gagal: Masih ada sesi aktif untuk $jurusan Semester $semester. Tutup sesi tersebut terlebih dahulu.';
      }

      await SupabaseService.createSesiAbsensi(
        mkId: selectedMK!,
        pertemuan_ke: _selectedPertemuanKe,
        materi: _materiController.text.isNotEmpty ? _materiController.text : null,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi absensi baru berhasil dibuka')),
      );
      // Reset selections
      setState(() {
        selectedMK = null;
        _selectedPertemuanKe = null;
        _materiController.clear();
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
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final role = await SupabaseService.getUserRole(user.id);
    var query = supabase.from('sesi_absensi').select('*, mata_kuliah(*)');

    if (role == 'dosen') {
      final mkData = await SupabaseService.getMataKuliah(dosenId: user.id);
      final mkIds = mkData.map((e) => e['id']).toList();
      if (mkIds.isNotEmpty) {
         query = query.filter('mata_kuliah_id', 'in', mkIds);
      } else {
        return [];
      }
    }

    final data = await query.order('tanggal', ascending: false);
    return data;
  }

  Future<void> tutupSesi(int id) async {
    await supabase.from('sesi_absensi').update({'is_open': false}).eq('id', id);
    setState(() {});
  }

  String _formatTanggal(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Kelola Sesi Absensi',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
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
                      color: Color(0xFF005F73),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: _selectedPertemuanKe,
                          hint: const Text('Ke-'),
                          items: List.generate(15, (index) => index + 1)
                              .map((e) => DropdownMenuItem<int>(
                                    value: e,
                                    child: Text('$e'),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPertemuanKe = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Pertemuan',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _materiController,
                          decoration: InputDecoration(
                            labelText: 'Materi Perkuliahan',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          loadingSubmit ? null : () => _handleBukaSesiBaru(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005F73),
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
                    final mkData = sesi['mata_kuliah'] ?? {};
                    final mkName = mkData['nama_mk'] ?? 'Mata Kuliah';
                    final pertemuanKe = sesi['pertemuan_ke'];
                    final materi = sesi['materi'];

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
                                  if(pertemuanKe != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Pertemuan Ke-$pertemuanKe',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                  if(materi != null && materi.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Materi: $materi',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  _infoIcon(Icons.location_on_rounded,
                                      'Radius: ${sesi['radius_meter']}m'),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF3B30),
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
                                        await tutupSesi(sesi['id']);
                                      },
                                      child: const Text(
                                        'Tutup Absensi',
                                        style: TextStyle(
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