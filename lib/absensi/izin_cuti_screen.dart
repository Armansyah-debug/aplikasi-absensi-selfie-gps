import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/supabase_service.dart';

const Color primaryBlue = Color(0xFF007AFF);

class IzinCutiScreen extends StatefulWidget {
  const IzinCutiScreen({super.key});

  @override
  State<IzinCutiScreen> createState() => _IzinCutiScreenState();
}

class _IzinCutiScreenState extends State<IzinCutiScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String name = '';
  String npm = '';
  String jenis = 'Izin';
  String alasan = '';

  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;

  XFile? _imageFile;
  Uint8List? _imageBytes;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  // ================= DATE =================
  Future<void> _selectDate(bool isMulai) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isMulai) {
          tanggalMulai = picked;
        } else {
          tanggalSelesai = picked;
        }
      });
    }
  }

  // ================= IMAGE =================
  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageFile = picked;
        _imageBytes = bytes;
      });
    }
  }

  // ================= SUBMIT (FIX FULL DEBUG) =================
  Future<void> _submit() async {
    if (name.isEmpty || npm.isEmpty || alasan.isEmpty) {
      _snack("Isi semua data dulu");
      return;
    }

    if (tanggalMulai == null || tanggalSelesai == null) {
      _snack("Tanggal belum lengkap");
      return;
    }

    if (_imageBytes == null) {
      _snack("Foto wajib diupload");
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      print("🚀 SUBMIT START");

      final fileName =
          'bukti_${npm}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      print("📤 UPLOAD IMAGE");

      final uploadedPath = await SupabaseService.uploadFile(
        bytes: _imageBytes!,
        fileName: fileName,
        bucketName: 'selfies',
      );

      print("📌 UPLOAD RESULT: $uploadedPath");

      if (uploadedPath == null) {
        throw "Upload gagal (null)";
      }

      print("💾 INSERT DB");

      await SupabaseService.insertIzin(
        name: name,
        npm: npm,
        jenis: jenis,
        alasan: alasan,
        tanggalMulai: tanggalMulai!,
        tanggalSelesai: tanggalSelesai!,
        fotoBuktiUrl: uploadedPath,
      );

      print("✅ SUCCESS");

      if (mounted) {
        Navigator.pop(context);
        _snack("Berhasil diajukan");
        Navigator.pop(context);
      }
    } catch (e) {
      print("❌ ERROR: $e");

      if (mounted) Navigator.pop(context);
      _snack("Error: $e");
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ================= DATE TILE =================
  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              date == null ? "Pilih" : _dateFormat.format(date),
              style: TextStyle(
                color: date == null ? Colors.grey : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Pengajuan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ================= NAMA & NPM =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Nama",
                    filled: true,
                    fillColor: const Color(0xFFF7F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "NPM",
                    filled: true,
                    fillColor: const Color(0xFFF7F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => npm = v,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ================= JENIS =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Jenis Pengajuan",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ["Izin", "Cuti", "Sakit"].map((e) {
                    final selected = jenis == e;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => jenis = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF4F86E0)
                                : const Color(0xFFF2F3F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              e,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ================= ALASAN =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextFormField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Alasan",
                filled: true,
                fillColor: const Color(0xFFF7F8FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => alasan = v,
            ),
          ),

          const SizedBox(height: 14),

          // ================= TANGGAL =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _dateTile(
                    "Tanggal Mulai", tanggalMulai, () => _selectDate(true)),
                const SizedBox(height: 10),
                _dateTile("Tanggal Selesai", tanggalSelesai,
                    () => _selectDate(false)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ================= UPLOAD =================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                OutlinedButton(
                  onPressed: _pickImage,
                  child: Text(
                    _imageFile == null ? "Upload Bukti Foto" : _imageFile!.name,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ================= BUTTON =================
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F86E0), Color(0xFF2F6BFF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: _submit,
              child: const Text(
                "KIRIM PENGAJUAN",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
