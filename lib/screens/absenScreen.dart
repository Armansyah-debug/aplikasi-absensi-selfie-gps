import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  final Color primaryBlue = Colors.blue.shade700;

  CameraController? _cameraController;
  Future<void>? _cameraInit;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isProcessing = false;
  String _status = 'Memuat kamera...';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

// Inisialisasi kamera depan
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

// Inisialisasi CameraController
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

// Mulai inisialisasi kamera
    _cameraInit = _cameraController!.initialize();
    await _cameraInit;

// Perbarui status setelah kamera siap
    if (mounted) {
      setState(() {
        _status = 'Posisikan wajah di dalam frame';
      });
    }
  }

// Mendapatkan lokasi dan alamat
  Future<Map<String, String>> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'GPS tidak aktif';
    }

// Minta izin lokasi
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Izin lokasi ditolak';
    }

// Dapatkan posisi saat ini
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

// Cek apakah lokasi palsu
    if (position.isMocked) throw 'Fake GPS terdeteksi';


// Dapatkan alamat dari koordinat
    final placemark = (await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    ))
        .first;

// Kembalikan lokasi dan alamat
    return {
      'lokasi': '${position.latitude},${position.longitude}',
      'alamat': '${placemark.subLocality ?? ''}, ${placemark.locality ?? ''}',
    };
  }

// Proses absen
  Future<void> _absen() async {
    if (_isProcessing) return;

// Mulai proses absen
    setState(() => _isProcessing = true);

// Tangani proses absen dengan try-catch
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User belum login';

      // Ambil foto
      final XFile photo = await _cameraController!.takePicture();

      // Deteksi wajah
      final faces = await _faceDetector.processImage(
        InputImage.fromFilePath(photo.path),
      );
      if (faces.isEmpty) throw 'Wajah tidak terdeteksi';

      // Input nama & NPM
      String nama = '';
      String npm = '';

// Tampilkan dialog input data
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Data Mahasiswa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nama'),
                onChanged: (v) => nama = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'NPM'),
                keyboardType: TextInputType.number,
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
              onPressed: () =>
                  Navigator.pop(context, {'nama': nama, 'npm': npm}),
              child: const Text('Absen'),
            ),
          ],
        ),
      );

// Validasi input data
      if (result == null ||
          result['nama']!.isEmpty ||
          result['npm']!.isEmpty) {
        throw 'Nama & NPM wajib diisi';
      }

// Dapatkan lokasi
      final location = await _getLocation();

// Upload selfie & simpan data absen
      final photoPath = await SupabaseService.uploadSelfie(
        File(photo.path),
        result['npm']!,
      );
      if (photoPath == null) throw 'Upload selfie gagal';

// Simpan data absen ke database
      await SupabaseService.insertAbsen(
        name: result['nama']!,
        npm: result['npm']!,
        location: location['lokasi']!,
        address: location['alamat']!,
        foto_path: photoPath,
      );

// Perbarui status sukses
      setState(() => _status = 'Absen berhasil ✅');
    } catch (e) {
      setState(() => _status = 'Gagal: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey.shade100,
    appBar: AppBar(
      title: const Text('Absen Hadir'),
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    body: FutureBuilder(
      future: _cameraInit,
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            /// ===== CAMERA AREA =====
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CameraPreview(_cameraController!),

                      /// FRAME WAJAH
                      Container(
                        width: 260,
                        height: 340,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /// ===== STATUS CARD =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            /// ===== BUTTON AREA =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _absen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    _isProcessing ? 'MEMPROSES...' : 'ABSEN SEKARANG',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}


  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}
