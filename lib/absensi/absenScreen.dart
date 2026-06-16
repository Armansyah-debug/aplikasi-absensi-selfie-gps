import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/tfjs_service.dart';
import '../main.dart'; // Akses global cameras

class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;

  Uint8List? _imageBytes;
  bool _loading = false;
  String _status = 'Siap absen';

  DateTime? _lastAbsen;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _initCamera();
    TfjsService.loadModel();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      setState(() => _status = 'Kamera tidak ditemukan');
      return;
    }

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ================= CAMERA =================
  Future<void> _takePhoto() async {
    if (!_isCameraReady || _controller == null) return;

    try {
      setState(() => _loading = true);
      final XFile photo = await _controller!.takePicture();
      final bytes = await photo.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _status = 'Foto siap';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Gagal ambil foto: $e';
        _loading = false;
      });
    }
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
      timeLimit: const Duration(seconds: 15),
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

      // ================= CEK PROFIL (AUTOMATION) =================
      setState(() => _status = 'Mengecek profil...');
      var profile = await SupabaseService.getUserProfile(user.id);

      String? nama = profile?['nama'];
      String? npm = profile?['npm'];

      // Jika data profil kosong, minta user melengkapi (HANYA SEKALI)
      if (nama == null || npm == null || nama.isEmpty || npm.isEmpty) {
        final input = await showDialog<Map<String, String>>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            String tempNama = '';
            String tempNpm = '';
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Lengkapi Profil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Data ini hanya perlu diisi sekali untuk mempermudah absensi selanjutnya.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => tempNama = v,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'NPM / ID',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => tempNpm = v,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    if (tempNama.isNotEmpty && tempNpm.isNotEmpty) {
                      Navigator.pop(context, {'n': tempNama, 'p': tempNpm});
                    }
                  },
                  child: const Text('Simpan & Lanjut'),
                ),
              ],
            );
          },
        );

        if (input == null) throw 'Lengkapi profil dulu';

        nama = input['n'];
        npm = input['p'];

        // Simpan ke database agar tidak diminta lagi
        await SupabaseService.updateProfile(
          userId: user.id,
          nama: nama!,
          npm: npm!,
        );
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
        npm!,
      );

      if (photoPath == null) throw 'Upload gagal';

      // ================= CEK SESI ABSENSI =================
      final sesi = await Supabase.instance.client
          .from('sesi_absensi')
          .select()
          .eq('is_open', true)
          .maybeSingle();

      if (sesi == null) {
        throw 'Belum ada sesi absensi yang dibuka';
      }

      await Supabase.instance.client.from('data_absensi').insert({
        'nama': nama,
        'npm': npm,
        'lokasi': '${pos.latitude},${pos.longitude}',
        'alamat': 'Koordinat: ${pos.latitude},${pos.longitude}',
        'foto_path': photoPath,
        'status': 'Hadir',
        'jenis': 'Hadir',
        'user_id': user.id,
        'waktu': now.toUtc().toIso8601String(),
        'is_mocked': pos.isMocked,
        'sesi_id': sesi['id'],
      });

      _lastAbsen = now;

      setState(() {
        _status = 'Absen berhasil ✅';
        _imageBytes = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Absen berhasil'),
            behavior: SnackBarBehavior.floating,
          ),
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
              child: Text(_status, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),

            const SizedBox(height: 16),

            // CAMERA PREVIEW CARD (iOS STYLE)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
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
                      : (_isCameraReady
                          ? CameraPreview(_controller!)
                          : const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            )),
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
                    onPressed: _imageBytes != null ? () => setState(() => _imageBytes = null) : _takePhoto,
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
                    child: Text(_imageBytes != null ? "Ulangi Foto" : "Ambil Foto"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading || _imageBytes == null ? null : _absen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _loading ? "..." : "Absen",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

