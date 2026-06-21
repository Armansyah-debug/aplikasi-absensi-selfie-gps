import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class KelolaMKScreen extends StatefulWidget {
  const KelolaMKScreen({super.key});

  @override
  State<KelolaMKScreen> createState() => _KelolaMKScreenState();
}

class _KelolaMKScreenState extends State<KelolaMKScreen> {
  List<Map<String, dynamic>> _listMK = [];
  List<Map<String, dynamic>> _listDosen = [];
  bool _isLoading = true;

  final List<String> _jurusanList = [
    'Informatika',
    'Sistem Informasi',
    'Manajemen',
    'Akuntansi',
  ];

  final List<int> _semesterList = List.generate(14, (index) => index + 1);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final mk = await SupabaseService.getAllMK();
    final dosen = await SupabaseService.getDosenList();
    setState(() {
      _listMK = mk;
      _listDosen = dosen;
      _isLoading = false;
    });
  }

  void _showForm({Map<String, dynamic>? mk}) {
    final isEdit = mk != null;
    final namaController = TextEditingController(text: isEdit ? mk['nama_mk'] : '');
    String? selectedJurusan = isEdit ? mk['jurusan'] : null;
    int? selectedSemester = isEdit ? mk['semester'] : null;
    String? selectedDosen = isEdit ? mk['dosen_id'] : null;
    final primaryColor = const Color(0xFF005F73);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Edit Mata Kuliah' : 'Tambah Mata Kuliah',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: namaController,
                  decoration: InputDecoration(
                    labelText: 'Nama Mata Kuliah',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedJurusan,
                  hint: const Text('Pilih Jurusan'),
                  items: _jurusanList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setModalState(() => selectedJurusan = v),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedSemester,
                  hint: const Text('Pilih Semester'),
                  items: _semesterList.map((e) => DropdownMenuItem(value: e, child: Text("Semester $e"))).toList(),
                  onChanged: (v) => setModalState(() => selectedSemester = v),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: selectedDosen,
                  hint: const Text('Pilih Dosen Pengampu'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('-- Belum ada dosen --'),
                    ),
                    ..._listDosen.map((e) => DropdownMenuItem<String?>(
                          value: e['id'].toString(),
                          child: Text(e['nama'] ?? '-'),
                        )),
                  ],
                  onChanged: (v) => setModalState(() => selectedDosen = v),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (namaController.text.isEmpty ||
                          selectedJurusan == null ||
                          selectedSemester == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lengkapi field wajib (Nama, Jurusan, Semester)')));
                        return;
                      }

                      if (isEdit) {
                        await SupabaseService.updateMK(
                          id: mk['id'],
                          namaMk: namaController.text.trim(),
                          jurusan: selectedJurusan!,
                          semester: selectedSemester!,
                          dosenId: selectedDosen,
                        );
                      } else {
                        await SupabaseService.insertMK(
                          namaMk: namaController.text.trim(),
                          jurusan: selectedJurusan!,
                          semester: selectedSemester!,
                          dosenId: selectedDosen,
                        );
                      }
                      
                      if (context.mounted) Navigator.pop(context);
                      _fetchData();
                    },
                    child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Mata Kuliah', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF005F73);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Kelola Mata Kuliah',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listMK.isEmpty
              ? const Center(child: Text('Belum ada data mata kuliah'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _listMK.length,
                  itemBuilder: (context, index) {
                    final mk = _listMK[index];
                    
                    final dosenData = _listDosen.firstWhere(
                      (d) => d['id'].toString() == mk['dosen_id'].toString(),
                      orElse: () => {},
                    );
                    final dosenName = dosenData['nama'] ?? 'Belum ada dosen';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey.shade100),
                      ),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        title: Text(mk['nama_mk'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text('${mk['jurusan']} • Semester ${mk['semester']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Dosen: $dosenName', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: primaryColor, size: 20),
                              onPressed: () => _showForm(mk: mk),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Hapus Mata Kuliah?'),
                                    content: const Text('Semua sesi absensi yang berhubungan dengan MK ini juga akan terhapus.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await SupabaseService.deleteMK(mk['id']);
                                  _fetchData();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah MK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
