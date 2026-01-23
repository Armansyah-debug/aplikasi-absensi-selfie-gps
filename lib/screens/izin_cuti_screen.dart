import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';

const Color primaryBlue = Color.fromARGB(255, 79, 134, 224);

class IzinCutiScreen extends StatefulWidget {
  const IzinCutiScreen({super.key});

  @override
  State<IzinCutiScreen> createState() => _IzinCutiScreenState();
}

class _IzinCutiScreenState extends State<IzinCutiScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _imageFile;
  Uint8List? _imageBytes; // Penting untuk upload via SupabaseService

  String name = '';
  String npm = '';
  String jenis = 'Izin';
  String alasan = '';
  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  // Fungsi pilih tanggal
  Future<void> _selectDate(BuildContext context, bool isMulai) async {
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

  // Fungsi ambil foto dari gallery
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Kompresi agar upload lebih cepat
    );
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageFile = pickedFile;
        _imageBytes = bytes;
      });
    }
  }

  // Fungsi utama untuk Kirim Data (Ajukan)
  Future<void> _submitForm() async {
    // 1. Validasi Form
    if (!_formKey.currentState!.validate()) return;

    // 2. Validasi Tanggal & Foto
    if (tanggalMulai == null || tanggalSelesai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai dan selesai')),
      );
      return;
    }
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lampirkan foto bukti')),
      );
      return;
    }

    try {
      // Tampilkan Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 3. Upload Foto menggunakan SupabaseService
      // Menggunakan bucket 'selfies' sesuai yang tersedia di service Anda
      final fileName = 'bukti_${npm}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadedPath = await SupabaseService.uploadFile(
        bytes: _imageBytes!,
        fileName: fileName,
        bucketName: 'selfies',
      );

      if (uploadedPath == null) throw 'Gagal mengunggah foto bukti';

      // 4. Simpan Data ke Database menggunakan SupabaseService
      await SupabaseService.insertIzin(
        name: name,
        npm: npm,
        jenis: jenis,
        alasan: alasan,
        tanggalMulai: tanggalMulai!,
        tanggalSelesai: tanggalSelesai!,
        fotoBuktiUrl: uploadedPath, // Mengirim path relatif (disimpan ke foto_path)
      );

      if (mounted) {
        Navigator.pop(context); // Tutup loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permohonan berhasil diajukan!')),
        );
        Navigator.pop(context); // Kembali ke halaman sebelumnya
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kesalahan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajukan Izin / Cuti / Sakit', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _textField(label: 'Nama', onChanged: (v) => name = v),
              const SizedBox(height: 16),
              _textField(label: 'NPM', onChanged: (v) => npm = v),
              const SizedBox(height: 16),
              const Text('Jenis Permintaan', style: TextStyle(fontWeight: FontWeight.bold)),
              _radioItem('Izin'),
              _radioItem('Cuti'),
              _radioItem('Sakit'),
              const SizedBox(height: 16),
              _textField(label: 'Alasan', onChanged: (v) => alasan = v),
              const SizedBox(height: 16),
              _dateField(label: 'Tanggal Mulai', date: tanggalMulai, onTap: () => _selectDate(context, true)),
              const SizedBox(height: 16),
              _dateField(label: 'Tanggal Selesai', date: tanggalSelesai, onTap: () => _selectDate(context, false)),
              const SizedBox(height: 20),
              
              // Preview Nama File
              if (_imageFile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'File terpilih: ${_imageFile!.name}',
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),

              ElevatedButton.icon(
                onPressed: _pickImage, 
                icon: const Icon(Icons.image), 
                label: const Text('Pilih Foto Lampiran'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                child: const Text('AJUKAN SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== UI HELPERS =====
  Widget _radioItem(String value) {
    return RadioListTile(
      title: Text(value),
      value: value,
      groupValue: jenis,
      activeColor: primaryBlue,
      contentPadding: EdgeInsets.zero,
      onChanged: (v) => setState(() => jenis = v!),
    );
  }

  Widget _textField({required String label, required Function(String) onChanged}) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: primaryBlue)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
      onChanged: onChanged,
    );
  }

  Widget _dateField({required String label, required DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: primaryBlue.withOpacity(0.5)), 
          borderRadius: BorderRadius.circular(8)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              date != null ? _dateFormat.format(date) : 'Pilih tanggal',
              style: TextStyle(color: date != null ? Colors.black : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
