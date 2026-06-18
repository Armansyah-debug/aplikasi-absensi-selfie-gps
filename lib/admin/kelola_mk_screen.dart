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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Mata Kuliah' : 'Tambah Mata Kuliah',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: namaController,
                  decoration: InputDecoration(
                    labelText: 'Nama Mata Kuliah',
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedSemester,
                  hint: const Text('Pilih Semester'),
                  items: _semesterList.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                  onChanged: (v) => setModalState(() => selectedSemester = v),
                  decoration: InputDecoration(
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Kelola Mata Kuliah', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listMK.isEmpty
              ? const Center(child: Text('Belum ada data mata kuliah'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listMK.length,
                  itemBuilder: (context, index) {
                    final mk = _listMK[index];
                    
                    // Manual mapping dosen name
                    final dosenData = _listDosen.firstWhere(
                      (d) => d['id'].toString() == mk['dosen_id'].toString(),
                      orElse: () => {},
                    );
                    final dosenName = dosenData['nama'] ?? 'Belum ada dosen';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(mk['nama_mk'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${mk['jurusan']} • Semester ${mk['semester']}'),
                            const SizedBox(height: 2),
                            Text('Dosen: $dosenName', style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showForm(mk: mk),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Hapus Mata Kuliah?'),
                                    content: const Text('Tindakan ini tidak dapat dibatalkan.'),
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
        backgroundColor: const Color(0xFF007AFF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah MK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
