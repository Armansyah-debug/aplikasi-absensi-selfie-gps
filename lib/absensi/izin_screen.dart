import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class IzinScreen extends StatefulWidget {
  const IzinScreen({super.key});

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen> {
  String _selectedJenis = "Izin";
  final TextEditingController _alasanController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  
  Uint8List? _imageBytes;
  bool _loading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF007AFF)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    // 1. VALIDASI FOTO WAJIB
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Foto bukti wajib diupload.")),
      );
      return;
    }

    if (_alasanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alasan harus diisi")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "User belum login";

      // ================= 1. CARI SESI AKTIF =================
      final profile = await SupabaseService.getUserProfile(user.id);
      final userJurusan = profile?['jurusan'];
      final userSemester = profile?['semester'];

      if (userJurusan == null || userSemester == null) {
        throw "Profil tidak lengkap (Jurusan/Semester kosong)";
      }

      final sesi = await Supabase.instance.client
          .from('sesi_absensi')
          .select('*, mata_kuliah!inner(jurusan, semester)')
          .eq('is_open', true)
          .eq('mata_kuliah.jurusan', userJurusan)
          .eq('mata_kuliah.semester', userSemester)
          .maybeSingle();

      if (sesi == null) {
        throw "Belum ada sesi absensi yang dibuka untuk $userJurusan Semester $userSemester";
      }

      // ================= 2. PROSES UPLOAD FOTO (WAJIB) =================
      final photoPath = await SupabaseService.uploadSelfieWeb(
        _imageBytes!,
        profile?['npm'] ?? 'izin',
      );
      
      if (photoPath == null) throw "Gagal upload foto bukti";

      // ================= 3. SIMPAN DATA =================
      final now = DateTime.now();
      final dateRangeStr = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";
      
      await Supabase.instance.client.from('data_absensi').insert({
        'nama': profile?['nama'],
        'npm': profile?['npm'],
        'lokasi': '0,0',
        'alamat': dateRangeStr, // SIMPAN RANGE TANGGAL DI KOLOM ALAMAT UNTUK IZIN/SAKIT
        'foto_path': photoPath,
        'status': _selectedJenis,
        'jenis': _selectedJenis,
        'alasan': _alasanController.text.trim(),
        'user_id': user.id,
        'waktu': now.toUtc().toIso8601String(),
        'sesi_id': sesi['id'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pengajuan berhasil dikirim")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          "Izin / Sakit",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // JENIS PENGAJUAN
          const Text(
            "Pilih Jenis",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: ["Izin", "Sakit"].map((e) {
              final isSelected = _selectedJenis == e;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedJenis = e),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF007AFF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        e,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // TANGGAL RANGE
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Mulai", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context, true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Akhir", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ALASAN
          const Text(
            "Alasan",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _alasanController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Masukkan alasan...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // LAMPIRAN (WAJIB)
          const Text(
            "Lampiran Foto (Wajib)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _imageBytes != null ? const Color(0xFF007AFF) : Colors.grey.shade300, 
                  style: BorderStyle.solid
                ),
              ),
              child: _imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade400, size: 40),
                        const SizedBox(height: 8),
                        Text("Tambah Foto Bukti", style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 40),

          // BUTTON SUBMIT
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "KIRIM PENGAJUAN",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
