import 'dart:typed_data';

class TfjsService {
  static bool _loaded = false;

  static Future<void> loadModel() async {
    // anggap model berhasil load
    _loaded = true;
  }

  static Future<bool> predictSelfie(Uint8List imageBytes) async {
    if (!_loaded) return false;

    // SIMULASI validasi wajah
    // (real TFJS terlalu panjang buat skripsi basic)
    return imageBytes.isNotEmpty;
  }
}
