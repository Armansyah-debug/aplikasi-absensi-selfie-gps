import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../../services/supabase_service.dart';
import '../../services/tfjs_service.dart';

class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  final Color primaryBlue = Colors.blue.shade700;

  html.VideoElement? _video;
  html.CanvasElement? _canvas;
  Uint8List? _imageBytes;
  bool _cameraReady = false;
  bool _isProcessing = false;
  String _status = 'Mengaktifkan kamera...';
  final String _viewId = 'camera-view-web-2026';

  @override
  void initState() {
    super.initState();
    TfjsService.loadModel();
    _initCamera();
  }

  // ================= CAMERA ENGINE =================
  Future<void> _initCamera() async {
    try {
      if (html.window.navigator.mediaDevices == null) throw 'Gunakan HTTPS untuk akses kamera';

      _video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.objectFit = 'cover';

      final stream = await html.window.navigator.mediaDevices!.getUserMedia({'video': true});
      _video!.srcObject = stream;

      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => _video!);

      _canvas = html.CanvasElement();
      setState(() {
        _cameraReady = true;
        _status = 'Kamera siap, ambil foto';
      });
    } catch (e) {
      setState(() => _status = 'Gagal kamera: $e');
    }
  }

  void _capturePhoto() async {
    if (_video == null || _video!.videoWidth == 0) return;
    
    _canvas!.width = _video!.videoWidth;
    _canvas!.height = _video!.videoHeight;
    _canvas!.context2D.drawImage(_video!, 0, 0);

    final blob = await _canvas!.toBlob('image/jpeg', 0.8);
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    reader.onLoadEnd.listen((_) {
      setState(() {
        _imageBytes = Uint8List.fromList(reader.result as List<int>);
        _status = 'Foto siap dikirim';
      });
    });
  }

  // ================= GEOLOCATION ENGINE (REVERSE GEOCODING) =================
  Future<Map<String, String>> _getLocationData() async {
    try {
      // 1. Ambil koordinat GPS
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final String lat = pos.latitude.toString();
      final String lon = pos.longitude.toString();
      String alamatFull = "Koordinat: $lat, $lon";

      // 2. Ambil Nama Alamat via API (OpenStreetMap Nominatim dengan Header Lengkap)
      try {
        final response = await http.get(
          Uri.parse('https://nominatim.openstreetmap.org'),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'AbsensiApp/1.0', // Wajib ada agar tidak diblokir OSM
          },
        ).timeout(const Duration(seconds: 7));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // 'display_name' berisi alamat lengkap (Jalan, Kelurahan, Kota, dll)
          alamatFull = data['display_name'] ?? alamatFull;
        }
      } catch (e) {
        debugPrint("Reverse Geocoding Error: $e");
      }

      return {
        'lokasi': '$lat,$lon',
        'alamat': alamatFull,
      };
    } catch (e) {
      throw 'Gagal mendeteksi lokasi: $e';
    }
  }

  // ================= ABSEN LOGIC =================
  Future<void> _absen() async {
    if (_imageBytes == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = 'Memproses absensi...';
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Sesi berakhir, silakan login ulang';

      // Dialog Input Nama & NPM
      String namaInput = '';
      String npmInput = '';

      final inputData = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi Identitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: const InputDecoration(labelText: 'Nama'), onChanged: (v) => namaInput = v),
              TextField(decoration: const InputDecoration(labelText: 'NPM'), onChanged: (v) => npmInput = v),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(context, {'n': namaInput, 'p': npmInput}), child: const Text('Kirim')),
          ],
        ),
      );

      if (inputData == null || inputData['n']!.isEmpty || inputData['p']!.isEmpty) {
        throw 'Data wajib diisi';
      }

      // 1. Dapatkan Lokasi & Alamat
      setState(() => _status = 'Sedang mencari alamat...');
      final locData = await _getLocationData();

      // 2. Upload Foto
      setState(() => _status = 'Mengunggah foto...');
      final photoPath = await SupabaseService.uploadSelfieWeb(_imageBytes!, inputData['p']!);
      if (photoPath == null) throw 'Upload gagal';

      // 3. Simpan ke Database
      setState(() => _status = 'Menyimpan data...');
      await SupabaseService.insertAbsen(
        name: inputData['n']!,
        npm: inputData['p']!,
        location: locData['lokasi']!,
        address: locData['alamat']!,
        foto_path: photoPath,
      );

      setState(() => _status = 'Absen Berhasil ✅');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil!')));

    } catch (e) {
      setState(() => _status = 'Gagal: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presensi Web 2026'), backgroundColor: primaryBlue, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: _cameraReady 
              ? HtmlElementView(viewType: _viewId) 
              : const Center(child: CircularProgressIndicator()),
          ),
          if (_imageBytes != null) 
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.memory(_imageBytes!, height: 120),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: _capturePhoto, child: const Text('FOTO'))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      onPressed: _isProcessing ? null : _absen,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
                      child: Text(_isProcessing ? '...' : 'ABSEN'),
                    )),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
