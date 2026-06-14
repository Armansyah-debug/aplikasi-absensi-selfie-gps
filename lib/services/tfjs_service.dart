import 'dart:typed_data';

class TfjsService {
  static bool _loaded = false;

  static Future<void> loadModel() async {
    _loaded = true;
  }

  // 🔥 FIX: tetap bool (simple & gak error)
  static Future<bool> predictSelfie(Uint8List imageBytes) async {
    if (!_loaded) return false;

    // SIMULASI FACE CHECK
    // real ML nanti bisa upgrade ke ML Kit / TFLite
    return imageBytes.isNotEmpty;
  }
}