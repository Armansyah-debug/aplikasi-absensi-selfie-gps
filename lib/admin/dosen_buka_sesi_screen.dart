import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class DosenBukaSesiScreen extends StatefulWidget {
  const DosenBukaSesiScreen({super.key});

  @override
  State<DosenBukaSesiScreen> createState() => _DosenBukaSesiScreenState();
}

class _DosenBukaSesiScreenState extends State<DosenBukaSesiScreen> {
  final supabase = Supabase.instance.client;

  List<dynamic> listMK = [];
  String? selectedMK;
  final _materiCtrl = TextEditingController();
  final _pertemuanCtrl = TextEditingController();

  bool loadingMK = false;
  bool loadingSubmit = false;
  bool _loadingPertemuan = false;

  @override
  void initState() {
    super.initState();
    _fetchMK();
  }

  @override
  void dispose() {
    _materiCtrl.dispose();
    _pertemuanCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMK() async {
    setState(() => loadingMK = true);
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await SupabaseService.getMataKuliah(dosenId: user.id);
      if (mounted) {
        setState(() {
          listMK = data;
          loadingMK = false;
        });
      }
    } else {
      if (mounted) setState(() => loadingMK = false);
    }
  }

  Future<void> _fetchNextPertemuan(String mkId) async {
    setState(() => _loadingPertemuan = true);
    try {
      final latestSession = await supabase
          .from('sesi_absensi')
          .select('pertemuan_ke')
          .eq('mata_kuliah_id', mkId)
          .order('pertemuan_ke', ascending: false)
          .limit(1)
          .maybeSingle();

      int nextPertemuan = 1;
      if (latestSession != null && latestSession['pertemuan_ke'] != null) {
        nextPertemuan = (latestSession['pertemuan_ke'] as int) + 1;
      }
      
      if (mounted) {
        setState(() {
          _pertemuanCtrl.text = nextPertemuan.toString();
        });
      }
    } catch (e) {
      debugPrint("Gagal fetch pertemuan: $e");
    } finally {
      if (mounted) setState(() => _loadingPertemuan = false);
    }
  }

  Future<void> _handleBukaSesiBaru() async {
    if (selectedMK == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Mata Kuliah terlebih dahulu')),
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
        throw 'Masih ada sesi aktif untuk $jurusan Semester $semester. Tutup sesi tersebut terlebih dahulu.';
      }

      int? pertemuanKe = int.tryParse(_pertemuanCtrl.text.trim());

      await SupabaseService.createSesiAbsensi(
        mkId: selectedMK!,
        pertemuan_ke: pertemuanKe,
        materi: _materiCtrl.text.isNotEmpty ? _materiCtrl.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi absensi berhasil dibuka!')),
        );
        Navigator.pop(context, true); // Return true indicating success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal buka sesi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loadingSubmit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Buka Sesi Baru',
          style: TextStyle(
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF4343D9), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Pilih mata kuliah untuk memulai sesi absensi mahasiswa.",
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF0051D5).withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form Mata Kuliah
              const Text(
                'Mata Kuliah',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1D20)),
              ),
              const SizedBox(height: 8),
              if (loadingMK)
                const Center(child: CircularPadding())
              else if (listMK.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text('Belum ada mata kuliah yang Anda ampu.', style: TextStyle(color: Colors.red)),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedMK,
                  decoration: InputDecoration(
                    hintText: 'Pilih Mata Kuliah',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF4343D9), width: 1.5),
                    ),
                  ),
                  items: listMK.map((mk) {
                    return DropdownMenuItem<String>(
                      value: mk['id'].toString(),
                      child: Text(
                        mk['nama_mk'] ?? 'Mata Kuliah',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedMK = val;
                    });
                    if (val != null) {
                      _fetchNextPertemuan(val);
                    }
                  },
                ),
              const SizedBox(height: 20),

              // Form Pertemuan Ke
              Row(
                children: [
                  const Text(
                    'Pertemuan Ke- (Opsional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1D20)),
                  ),
                  if (_loadingPertemuan) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pertemuanCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Contoh: 1, 2, 3...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF4343D9), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Materi
              const Text(
                'Materi Pembahasan (Opsional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1D20)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _materiCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tuliskan deskripsi singkat materi...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF4343D9), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Buka Sesi
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loadingSubmit ? null : _handleBukaSesiBaru,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0051D5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: loadingSubmit
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Buka Sesi Sekarang',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CircularPadding extends StatelessWidget {
  const CircularPadding({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: CircularProgressIndicator(),
    );
  }
}
