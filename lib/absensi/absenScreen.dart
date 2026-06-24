import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
  Map<String, dynamic>? _activeSesi;
  bool _fetchingSesi = true;
  bool _alreadyAbsen = false;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadInitialData();
    TfjsService.loadModel();
  }

  Future<void> _loadInitialData() async {
    await _checkActiveSesi();
  }

  Future<void> _checkActiveSesi() async {
    setState(() => _fetchingSesi = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await SupabaseService.getUserProfile(user.id);
      final userJurusan = profile?['jurusan'];
      final userSemester = profile?['semester'];

      if (userJurusan != null && userSemester != null) {
        final sesi = await Supabase.instance.client
            .from('sesi_absensi')
            .select('*, mata_kuliah!inner(*)')
            .eq('is_open', true)
            .eq('mata_kuliah.jurusan', userJurusan)
            .eq('mata_kuliah.semester', userSemester)
            .maybeSingle();

        bool alreadyAbsen = false;
        if (sesi != null) {
          final existing = await Supabase.instance.client
              .from('data_absensi')
              .select('id')
              .eq('user_id', user.id)
              .eq('sesi_id', sesi['id'])
              .neq('jenis', 'Pelanggaran')
              .maybeSingle();
          alreadyAbsen = existing != null;
        }

        setState(() {
          _activeSesi = sesi;
          _alreadyAbsen = alreadyAbsen;
        });
      }
    } catch (e) {
      debugPrint('Check Sesi Error: $e');
    } finally {
      setState(() => _fetchingSesi = false);
    }
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

      // ================= CEK SESI ABSENSI =================
      if (_activeSesi == null) throw 'Belum ada sesi absensi aktif';

      // ================= VALIDASI PROFIL =================
      setState(() => _status = 'Mengecek profil...');
      var profile = await SupabaseService.getUserProfile(user.id);
      String? nama = profile?['nama'];
      String? npm = profile?['npm'];

      if (nama == null || npm == null || nama.isEmpty || npm.isEmpty) {
        throw 'Lengkapi profil (Nama/NPM) di pengaturan terlebih dahulu';
      }

      // ================= ANTI SPAM =================
      final now = DateTime.now();
      if (_lastAbsen != null) {
        final diff = now.difference(_lastAbsen!).inMinutes;
        if (diff < 5) throw 'Tunggu 5 menit untuk absen lagi';
      }

      // ================= VALIDASI DUPLIKAT ABSENSI (Server Side) =================
      setState(() => _status = 'Mengecek data absen...');
      final existingAbsen = await Supabase.instance.client
          .from('data_absensi')
          .select('id')
          .eq('user_id', user.id)
          .eq('sesi_id', _activeSesi!['id'])
          .neq('jenis', 'Pelanggaran')
          .maybeSingle();

      if (existingAbsen != null) {
        setState(() => _alreadyAbsen = true);
        throw 'Anda sudah melakukan absensi pada sesi ini.';
      }

      // ================= ALUR HADIR =================
      setState(() => _status = 'Validasi wajah...');
      await _checkFace();

      setState(() => _status = 'Ambil lokasi...');
      final pos = await _getPosition();
      final lokasi = '${pos.latitude},${pos.longitude}';

      if (pos.isMocked) {
        setState(() => _status = 'Mengecek data pelanggaran...');
        final existingViolation = await Supabase.instance.client
            .from('data_absensi')
            .select('id')
            .eq('user_id', user.id)
            .eq('sesi_id', _activeSesi!['id'])
            .eq('jenis', 'Pelanggaran')
            .maybeSingle();

        if (existingViolation != null) {
          throw 'Fake GPS terdeteksi. Pelanggaran telah dicatat sebelumnya.';
        }

        setState(() => _status = 'Mencatat pelanggaran...');
        String alamat = 'Koordinat: $lokasi';
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            alamat = [p.street, p.subLocality, p.locality, p.subAdministrativeArea]
                .where((e) => e != null && e.isNotEmpty)
                .join(', ');
          }
        } catch (_) {}

        await Supabase.instance.client.from('data_absensi').insert({
          'nama': nama,
          'npm': npm,
          'lokasi': lokasi,
          'alamat': alamat,
          'foto_path': '-',
          'status': 'Ditolak (Fake GPS)',
          'jenis': 'Pelanggaran',
          'user_id': user.id,
          'waktu': now.toUtc().toIso8601String(),
          'is_mocked': true,
          'sesi_id': _activeSesi!['id'],
        });

        throw 'Fake GPS terdeteksi. Nonaktifkan aplikasi mock location dan coba kembali.';
      }

      setState(() => _status = 'Mencari alamat...');
      String alamat = '-';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          alamat = [p.street, p.subLocality, p.locality, p.subAdministrativeArea]
              .where((e) => e != null && e.isNotEmpty)
              .join(', ');
        }
      } catch (_) {
        alamat = 'Koordinat: $lokasi';
      }

      setState(() => _status = 'Upload foto...');
      final photoPath = await SupabaseService.uploadSelfieWeb(_imageBytes!, npm);
      if (photoPath == null) throw 'Upload foto gagal';

      // ================= SIMPAN DATA =================
      setState(() => _status = 'Menyimpan data...');

      await Supabase.instance.client.from('data_absensi').insert({
        'nama': nama,
        'npm': npm,
        'lokasi': lokasi,
        'alamat': alamat,
        'foto_path': photoPath,
        'status': 'Hadir',
        'jenis': 'Hadir',
        'user_id': user.id,
        'waktu': now.toUtc().toIso8601String(),
        'is_mocked': pos.isMocked,
        'sesi_id': _activeSesi!['id'],
      });

      _lastAbsen = now;
      setState(() {
        _status = 'Absensi berhasil ✅';
        _imageBytes = null;
        _alreadyAbsen = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Absensi Hadir berhasil disimpan')),
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
        title: const Text('Absen Hadir'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSesiInfo(),
            const SizedBox(height: 16),
            
            // CAMERA PREVIEW
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                height: 350,
                decoration: const BoxDecoration(color: Colors.black),
                child: _imageBytes != null
                    ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                    : (_isCameraReady
                        ? CameraPreview(_controller!)
                        : const Center(child: CircularProgressIndicator(color: Colors.white))),
              ),
            ),

            const SizedBox(height: 16),

            // BUTTON ACTIONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(_imageBytes != null ? "Ulangi Foto" : "Ambil Selfie"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || _imageBytes == null || _activeSesi == null || _alreadyAbsen) ? null : _absen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _alreadyAbsen ? Colors.grey : const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _alreadyAbsen ? "ANDA SUDAH ABSEN" : "KIRIM KEHADIRAN",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildSesiInfo() {
    if (_fetchingSesi) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_activeSesi == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, color: Colors.red.shade400, size: 32),
            const SizedBox(height: 12),
            const Text(
              "Belum ada sesi absensi yang dibuka",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              "Silakan hubungi dosen pengampu mata kuliah Anda.",
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final mk = _activeSesi!['mata_kuliah'];
    final namaMK = mk['nama_mk'] ?? '-';
    final jurusan = mk['jurusan'] ?? '-';
    final semester = mk['semester'] ?? '-';
    final pertemuanKe = _activeSesi!['pertemuan_ke']; // Ambil pertemuan_ke
    final materi = _activeSesi!['materi']; // Ambil materi

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFF007AFF), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  namaMK,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.school_outlined, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(
                "$jurusan - Semester $semester",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10), // Tambah spasi

          // PERTEMUAN KE
          if (pertemuanKe != null)
            Row(
              children: [
                const Icon(Icons.numbers_rounded, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Pertemuan Ke-$pertemuanKe",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          
          // MATERI
          if (materi != null && materi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0), // Spasi atas untuk materi
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      materi,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          if (_alreadyAbsen)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Anda sudah pernah melakukan absensi di sesi ini.",
                      style: TextStyle(fontSize: 13, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
