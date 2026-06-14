import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/tfjs_service.dart';

class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _loading = false;
  String _status = 'Siap absen';

  DateTime? _lastAbsen;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();

    // 🔥 PENTING: ini yang kamu kurang tadi
    TfjsService.loadModel();
  }

  // ================= CAMERA =================
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (photo == null) return;

    _imageBytes = await photo.readAsBytes();

    setState(() {
      _status = 'Foto siap';
    });
  }

  // ================= GPS =================
  Future<Position> _getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'GPS tidak aktif';

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Izin lokasi ditolak';
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (pos.isMocked) {
      throw 'Fake GPS terdeteksi';
    }

    return pos;
  }

  // ================= FACE CHECK =================
  Future<void> _checkFace() async {
    if (_imageBytes == null) {
      throw 'Foto belum diambil';
    }

    final isValid = await TfjsService.predictSelfie(_imageBytes!);

    if (!isValid) {
      throw 'Wajah tidak valid / tidak terdeteksi';
    }
  }

  // ================= ABSEN =================
  Future<void> _absen() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _status = 'Memproses...';
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User belum login';

      // ================= INPUT =================
      String nama = '';
      String npm = '';

      final input = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Data Absen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nama'),
                onChanged: (v) => nama = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'NPM'),
                onChanged: (v) => npm = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {'n': nama, 'p': npm}),
              child: const Text('Absen'),
            ),
          ],
        ),
      );

      if (input == null || input['n']!.isEmpty || input['p']!.isEmpty) {
        throw 'Data tidak boleh kosong';
      }

      // ================= ANTI SPAM =================
      final now = DateTime.now();

      if (_lastAbsen != null) {
        final diff = now.difference(_lastAbsen!).inMinutes;
        if (diff < 5) {
          throw 'Tunggu 5 menit untuk absen lagi';
        }
      }

      // ================= FACE CHECK =================
      setState(() => _status = 'Validasi wajah...');
      await _checkFace();

      // ================= GPS =================
      setState(() => _status = 'Ambil lokasi...');
      final pos = await _getPosition();

      // ================= UPLOAD =================
      setState(() => _status = 'Upload data...');

      final photoPath = await SupabaseService.uploadSelfieWeb(
        _imageBytes!,
        input['p']!,
      );

      if (photoPath == null) throw 'Upload gagal';

      final currentTime = DateTime.now();
      await Supabase.instance.client.from('data_absensi').insert({
        'nama': input['n']!,
        'npm': input['p']!,
        'lokasi': '${pos.latitude},${pos.longitude}',
        'alamat': 'Koordinat: ${pos.latitude},${pos.longitude}',
        'foto_path': photoPath,
        'status': 'Hadir',
        'jenis': 'Hadir',
        'user_id': user.id,
        'waktu': now.toIso8601String(),
        'is_mocked': pos.isMocked,
      });

      _lastAbsen = now;

      setState(() => _status = 'Absen berhasil ✅');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Absen berhasil')),
        );
      }
    } catch (e) {
      setState(() => _status = 'Gagal: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Absen'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // STATUS PILL
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(_status),
            ),

            const SizedBox(height: 16),

            // CAMERA PREVIEW CARD (iOS STYLE)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Text(
                            'Belum ada foto',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // GLASS INFO CARD
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    "Pastikan wajah terlihat jelas + GPS aktif",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // BUTTON ACTIONS (iOS STYLE)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _takePhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),
                    child: const Text("Ambil Foto"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _absen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _loading ? "..." : "Absen",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
